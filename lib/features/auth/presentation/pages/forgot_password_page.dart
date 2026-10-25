import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/account_repository.dart';
import '../../domain/identity_validators.dart';

/// Password recovery: `request_password_reset` e-mails a one-time code (the
/// answer never reveals whether the account exists), then
/// `confirm_password_reset` sets the new password with that code. Opened only
/// when `recovery_status.available` is true.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage(
      {required this.repository, this.initialIdentifier = '', super.key});
  final AccountRepository repository;
  final String initialIdentifier;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _identifier = TextEditingController(text: widget.initialIdentifier);
  bool _busy = false;
  bool _sent = false;
  bool _done = false;
  int _minutes = 30;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    if (_identifier.text.trim().isEmpty) {
      setState(() => _error = 'نام کاربری یا ایمیل را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final minutes =
          await widget.repository.requestPasswordReset(_identifier.text);
      if (mounted) {
        setState(() {
          _sent = true;
          _minutes = minutes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = failureDetail(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _DonePage(
          key: const Key('reset_done'),
          message: 'رمز عبور جدید ثبت شد. با رمز تازه وارد شوید.');
    }
    if (_sent) {
      return CodePasswordPage(
        title: 'بازیابی رمز عبور',
        intro:
            'اگر حسابی با این مشخصات وجود داشته باشد، کد یک‌بارمصرف برای آن ارسال شد (اعتبار ${toPersianDigits(_minutes)} دقیقه). کد و رمز جدید را وارد کنید.',
        identifier: _identifier.text.trim(),
        submitLabel: 'ثبت رمز جدید',
        onSubmit: (code, password, repeat) =>
            widget.repository.confirmPasswordReset(
                identifier: _identifier.text,
                code: code,
                newPassword: password,
                repeatPassword: repeat),
        onDone: () => setState(() => _done = true),
      );
    }
    return Scaffold(
      appBar:
          const AsoudHeader(title: 'بازیابی رمز عبور', subtitle: 'آسود ERP'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'نام کاربری یا ایمیل حساب خود را وارد کنید تا کد بازیابی برای ایمیل حساب ارسال شود.',
            style: TextStyle(color: AsoudColors.muted, height: 1.8)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('reset_identifier'),
          controller: _identifier,
          enabled: !_busy,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          onSubmitted: (_) => _request(),
          decoration: const InputDecoration(
              labelText: 'نام کاربری یا ایمیل',
              prefixIcon: Icon(Icons.person_outline_rounded)),
        ),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!,
                  style: const TextStyle(color: AsoudColors.danger))),
      ]),
      bottomNavigationBar: AsoudBottomActions(
        primaryLabel: _busy ? 'در حال ارسال…' : 'ارسال کد بازیابی',
        onPrimary: _busy ? null : _request,
      ),
    );
  }
}

/// Invitation activation: the invited person enters the account, the code from
/// the invitation e-mail (valid 72 hours) and chooses a personal password.
class ActivateAccountPage extends StatefulWidget {
  const ActivateAccountPage(
      {required this.repository, this.initialIdentifier = '', super.key});
  final AccountRepository repository;
  final String initialIdentifier;

  @override
  State<ActivateAccountPage> createState() => _ActivateAccountPageState();
}

class _ActivateAccountPageState extends State<ActivateAccountPage> {
  late final _identifier = TextEditingController(text: widget.initialIdentifier);
  bool _done = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _done
      ? const _DonePage(
          key: Key('activation_done'),
          message: 'حساب شما فعال شد. با رمز تازه وارد شوید.')
      : CodePasswordPage(
          title: 'فعال‌سازی حساب',
          intro:
              'نام کاربری (ایمیل) و کد دعوت‌نامه را وارد کنید و رمز عبور شخصی خود را بسازید.',
          identifierController: _identifier,
          submitLabel: 'فعال‌سازی حساب',
          onSubmit: (code, password, repeat) =>
              widget.repository.activateAccount(
                  identifier: _identifier.text,
                  code: code,
                  newPassword: password,
                  repeatPassword: repeat),
          onDone: () => setState(() => _done = true),
        );
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(title: 'آسود ERP', subtitle: 'حساب کاربری'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 56, color: AsoudColors.success),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: const TextStyle(height: 1.8)),
        ]),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'بازگشت به ورود',
          onPrimary: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      );
}

/// One-time code + new password form shared by reset and activation. All
/// other validation (policy, code, attempts) is the server's.
class CodePasswordPage extends StatefulWidget {
  const CodePasswordPage({
    required this.title,
    required this.intro,
    required this.submitLabel,
    required this.onSubmit,
    required this.onDone,
    this.identifier,
    this.identifierController,
    super.key,
  });
  final String title;
  final String intro;
  final String submitLabel;
  final String? identifier;
  final TextEditingController? identifierController;
  final Future<void> Function(String code, String password, String repeat)
      onSubmit;
  final VoidCallback onDone;

  @override
  State<CodePasswordPage> createState() => _CodePasswordPageState();
}

class _CodePasswordPageState extends State<CodePasswordPage> {
  final _code = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _touched = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String? get _codeError =>
      _code.text.trim().isEmpty ? 'کد را وارد کنید.' : null;
  String? get _newError => PasswordPolicy.newPassword(_new.text);
  String? get _repeatError => PasswordPolicy.repeat(_repeat.text, _new.text);

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _touched = true);
    final idMissing = widget.identifierController != null &&
        widget.identifierController!.text.trim().isEmpty;
    if (idMissing ||
        _codeError != null ||
        _newError != null ||
        _repeatError != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_code.text, _new.text, _repeat.text);
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = failureDetail(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pw(String label, TextEditingController c, String? error, Key key) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: key,
          controller: c,
          enabled: !_busy,
          obscureText: true,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: label,
              errorText: _touched ? error : null,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.lock_outline_rounded)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(title: widget.title, subtitle: 'آسود ERP'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(widget.intro,
              key: const Key('code_intro'),
              style: const TextStyle(color: AsoudColors.muted, height: 1.8)),
          const SizedBox(height: 14),
          if (widget.identifierController != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: const Key('code_identifier'),
                controller: widget.identifierController,
                enabled: !_busy,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: 'نام کاربری یا ایمیل',
                    errorText: _touched &&
                            widget.identifierController!.text.trim().isEmpty
                        ? 'نام کاربری را وارد کنید.'
                        : null,
                    prefixIcon: const Icon(Icons.person_outline_rounded)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: const Key('code_field'),
              controller: _code,
              enabled: !_busy,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: 'کد یک‌بارمصرف',
                  errorText: _touched ? _codeError : null,
                  prefixIcon: const Icon(Icons.pin_outlined)),
            ),
          ),
          _pw('رمز عبور جدید', _new, _newError, const Key('code_new_password')),
          _pw('تکرار رمز عبور جدید', _repeat, _repeatError,
              const Key('code_repeat_password')),
          if (_error != null)
            Text(_error!,
                key: const Key('code_error'),
                style: const TextStyle(color: AsoudColors.danger)),
        ]),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: _busy ? 'در حال ثبت…' : widget.submitLabel,
          onPrimary: _busy ? null : _submit,
        ),
      );
}
