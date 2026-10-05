import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../data/demo_choice_store.dart';
import '../../data/demo_transfer_service.dart';
import '../../domain/repositories/auth_repository.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/data/workflow_automation_repository.dart';
import '../../../workflows/domain/entities/document_template.dart';
import 'demo_transfer_page.dart';

/// Server sign-in. The offline demo preview is a secondary, explicit choice.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, bool? showDemoButton, this.transferService})
      : showDemoButton = showDemoButton ?? AppConfig.offlineDemoMode;

  /// `OFFLINE_DEMO_MODE` only decides whether the demo entry exists.
  /// Exposed as a parameter so widget tests can cover both values even
  /// though the flag itself is compile-time.
  final bool showDemoButton;

  /// Overridable for tests; defaults to the on-device preview stores.
  final DemoTransferService? transferService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverUrl = TextEditingController(text: AppConfig.erpNextBaseUrl);
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    if (_busy) return;
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
      await _afterLogin();
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

  /// A demo user signing into a real account is offered the one-time
  /// transfer of rows created in the preview.
  Future<void> _afterLogin() async {
    final client = context.read<FrappeApiClient>();
    final service = widget.transferService ?? DemoTransferService();
    final candidates = await service.listCandidates();
    final seen = await DemoTransferService.isTransferSeen();
    if (!mounted) return;
    if (candidates.isNotEmpty && !seen) {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => DemoTransferPage(
                service: service,
                submitRequest: (data) => _submitRequest(client, data),
                submitTemplate: (template) => _submitTemplate(client, template),
              )));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DashboardLandingPage()),
      (_) => false,
    );
  }

  Future<void> _submitRequest(
      FrappeApiClient client, Map<String, dynamic> data) async {
    final company = '${data['company'] ?? ''}';
    final payload = Map<String, dynamic>.from(data)
      ..remove('company')
      ..remove('request_id')
      ..remove('is_sample');
    await GenericRequestRepository(client, company).create(
        {...payload, 'company': company}, GenericRequestRepository.requestId());
  }

  Future<void> _submitTemplate(
      FrappeApiClient client, Map<String, dynamic> template) async {
    final row = Map<String, dynamic>.from(template)..remove('is_sample');
    await WorkflowAutomationRepository(client).saveTemplate(
      company: '${row['company'] ?? ''}',
      template: DocumentTemplate.fromJson(row),
    );
  }

  Future<void> _openDemo() async {
    await DemoChoiceStore.setDemoChosen(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const DashboardLandingPage(
              offlinePreview: true,
            )));
  }

  @override
  void dispose() {
    _serverUrl.dispose();
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
                    const Text('ورود به حساب کاربری ASOUD ERP',
                        style:
                            TextStyle(fontSize: 11, color: AsoudColors.muted)),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _serverUrl,
                      readOnly: true,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'نشانی سرور',
                        prefixIcon: Icon(Icons.cloud_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _username,
                      enabled: !_busy,
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
                      enabled: !_busy,
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
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        child: Text(_busy ? 'در حال ورود…' : 'ورود'),
                      ),
                    ),
                    if (widget.showDemoButton) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _openDemo,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('ورود به نسخه نمایشی (آفلاین)'),
                        ),
                      ),
                    ],
                  ]),
            ),
          ),
        ),
      );
}
