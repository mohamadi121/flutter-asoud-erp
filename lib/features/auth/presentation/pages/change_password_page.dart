import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/account_repository.dart';
import '../../data/saved_credentials_store.dart';
import '../../domain/identity_validators.dart';
import '../../domain/repositories/auth_repository.dart';

/// The single change-password screen. It is opened from the admin initial
/// profile form, from the forced temporary-password step, and from
/// بیشتر ← حساب کاربری ← امنیت حساب ← تغییر رمز عبور, always with the same
/// server service.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage(
      {required this.repository,
      this.forced = false,
      this.onChanged,
      this.credentials,
      super.key});
  final AccountRepository repository;

  /// A temporary password must be replaced before anything else: no way back.
  final bool forced;

  /// Called after success instead of popping (forced flow).
  final VoidCallback? onChanged;
  final SavedCredentialsStore? credentials;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _showCurrent = false, _showNew = false, _showRepeat = false;
  bool _busy = false;
  bool _touched = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String? get _currentError =>
      _current.text.isEmpty ? 'رمز عبور فعلی را وارد کنید.' : null;
  String? get _newError =>
      PasswordPolicy.newPassword(_new.text, current: _current.text);
  String? get _repeatError => PasswordPolicy.repeat(_repeat.text, _new.text);
  bool get _valid =>
      _currentError == null && _newError == null && _repeatError == null;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _touched = true);
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.changePassword(
          currentPassword: _current.text,
          newPassword: _new.text,
          repeatPassword: _repeat.text);
      // The saved password (if any) is stale now; sign in again with the new
      // one and replace it. A wrong current password never reaches this line:
      // the server answers HTTP 417 with its Persian sentence (shown below)
      // and the session stays signed in.
      if (result.reauthenticationRequired) await _refreshSession(_new.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رمز عبور جدید ثبت شد.')));
      if (widget.onChanged != null) {
        widget.onChanged!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = failureDetail(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Other sessions are revoked by the server, so the device signs in again
  /// with the new password and refreshes a saved one only if the user had
  /// opted in (otherwise the old saved password is removed).
  Future<void> _refreshSession(String password) async {
    try {
      final client = context.read<FrappeApiClient>();
      final auth = context.read<AuthRepository>();
      final store = widget.credentials ?? SavedCredentialsStore();
      final server = client is FrappeClient ? client.serverIdentity : null;
      final me = await client.getCurrentUser();
      final typed = server == null ? null : await store.lastUsername(server);
      final name = typed ?? me.userId;
      if (server != null) {
        final hadSaved = await store.hasPassword(server, name);
        if (hadSaved) await store.deletePassword(server, name);
        await auth.signIn(username: name, password: password);
        if (hadSaved) await store.savePassword(server, name, password);
      }
    } catch (_) {
      // The password is already changed; a failed silent sign-in surfaces on
      // the next request as a normal expired session.
    }
  }

  Widget _field(String label, TextEditingController c, bool shown,
          VoidCallback toggle, String? error, Key key,
          {List<String>? hints}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: key,
          controller: c,
          enabled: !_busy,
          obscureText: !shown,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: hints,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            errorText: _touched ? error : null,
            errorMaxLines: 3,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: shown ? 'پنهان‌کردن رمز عبور' : 'نمایش رمز عبور',
              icon: Icon(shown
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: toggle,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.forced,
        child: Scaffold(
          appBar: AsoudHeader(
              title: 'تغییر رمز عبور',
              subtitle: widget.forced
                  ? 'رمز موقت باید پیش از ادامه تغییر کند'
                  : 'امنیت حساب'),
          body: SafeArea(
            child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  AutofillGroup(
                    child: Column(children: [
                      _field(
                          'رمز عبور فعلی',
                          _current,
                          _showCurrent,
                          () => setState(() => _showCurrent = !_showCurrent),
                          _currentError,
                          const Key('current_password'),
                          hints: const [AutofillHints.password]),
                      _field(
                          'رمز عبور جدید',
                          _new,
                          _showNew,
                          () => setState(() => _showNew = !_showNew),
                          _newError,
                          const Key('new_password'),
                          hints: const [AutofillHints.newPassword]),
                      _field(
                          'تکرار رمز عبور جدید',
                          _repeat,
                          _showRepeat,
                          () => setState(() => _showRepeat = !_showRepeat),
                          _repeatError,
                          const Key('repeat_password'),
                          hints: const [AutofillHints.newPassword]),
                    ]),
                  ),
                  const Text(
                      'رمز جدید دست‌کم ۱۲ نویسه باشد و با رمز فعلی یکسان نباشد.',
                      style:
                          TextStyle(fontSize: 12, color: AsoudColors.muted)),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            key: const Key('password_error'),
                            style:
                                const TextStyle(color: AsoudColors.danger))),
                ]),
          ),
          bottomNavigationBar: AsoudBottomActions(
            primaryLabel: _busy ? 'در حال ثبت…' : 'ثبت رمز جدید',
            onPrimary: _busy ? null : _submit,
            secondaryLabel: widget.forced ? null : 'بازگشت بدون تغییر',
            onSecondary: _busy ? null : () => Navigator.of(context).pop(false),
          ),
        ),
      );
}
