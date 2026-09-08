import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/auth_repository.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

/// Preview builds remain usable without a server; connected builds sign in.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;
  Future<void> _login() async {
    if (_busy || AppConfig.offlineDemoMode) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'نام کاربری و رمز عبور را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<AuthRepository>()
          .signIn(username: _username.text.trim(), password: _password.text);
      _password.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => const DashboardLandingPage()));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'ورود ممکن نشد؛ اتصال و ذخیره امن گوشی را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                        AppConfig.offlineDemoMode
                            ? 'ورود به حساب کاربری پس از آماده‌شدن سرور ASOUD ERP فعال می‌شود.'
                            : 'ورود به حساب کاربری ASOUD ERP',
                        style:
                            TextStyle(fontSize: 11, color: AsoudColors.muted)),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _username,
                      enabled: !AppConfig.offlineDemoMode && !_busy,
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
                      enabled: !AppConfig.offlineDemoMode && !_busy,
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
                    if (AppConfig.offlineDemoMode) const _LoginUnavailable(),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            AppConfig.offlineDemoMode || _busy ? null : _login,
                        child: Text(AppConfig.offlineDemoMode
                            ? 'ورود تا آماده‌شدن سرور غیرفعال است'
                            : _busy
                                ? 'در حال ورود…'
                                : 'ورود'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                              builder: (_) => const DashboardLandingPage(
                                    offlinePreview: true,
                                  )),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('ادامه موقت بدون ورود'),
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
                'سرور ASOUD ERP هنوز برای اتصال آماده نیست؛ ورود عمداً غیرفعال است.',
                style: TextStyle(fontSize: 9)),
          ),
        ]),
      );
}
