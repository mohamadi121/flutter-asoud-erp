import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../office_setup/presentation/pages/offices_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<FrappeApiClient>().login(
            username: _username.text,
            password: _password.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OfficesPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'ورود به ERPNext انجام نشد. نام کاربری، رمز عبور و اتصال به سرور را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
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
                          'برای ورود به دفترهای کاری خود، اطلاعات ERPNext را وارد کنید.',
                          style: TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _username,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'نام کاربری یا ایمیل',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'نام کاربری را وارد کنید.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'رمز عبور را وارد کنید.'
                            : null,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _LoginError(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _submitting ? null : _login,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 21,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('ورود به حساب کاربری'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'حساب کاربری توسط مدیر سیستم ERPNext ایجاد می‌شود.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      );
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AsoudColors.danger.withValues(alpha: .07),
          border: Border.all(color: AsoudColors.danger.withValues(alpha: .25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AsoudColors.danger, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 9))),
        ]),
      );
}
