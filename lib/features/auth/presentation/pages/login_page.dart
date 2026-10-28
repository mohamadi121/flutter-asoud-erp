import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/data/workflow_automation_repository.dart';
import '../../../workflows/domain/entities/document_template.dart';
import '../../data/account_repository.dart';
import '../../data/demo_choice_store.dart';
import '../../data/demo_transfer_service.dart';
import '../../data/saved_credentials_store.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/server_url_policy.dart';
import 'demo_transfer_page.dart';
import 'forgot_password_page.dart';
import 'post_login_page.dart';
import 'setup_reset_page.dart';

T? _tryRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}

/// Server sign-in. The offline demo preview is a secondary, explicit choice.
///
/// One compact RTL column that fits a normal phone without scrolling and
/// scrolls only when the keyboard or a large font needs the room. No field is
/// ever removed to save space, and there is no biometric sign-in.
class LoginPage extends StatefulWidget {
  const LoginPage(
      {super.key,
      bool? showDemoButton,
      this.transferService,
      this.initialServerUrl,
      this.credentials,
      this.urlPolicy = const ServerUrlPolicy(),
      this.notice})
      : showDemoButton = showDemoButton ?? AppConfig.offlineDemoMode;

  /// `OFFLINE_DEMO_MODE` only decides whether the demo entry exists.
  /// Exposed as a parameter so widget tests can cover both values even
  /// though the flag itself is compile-time.
  final bool showDemoButton;

  /// Overridable for tests; defaults to the on-device preview stores.
  final DemoTransferService? transferService;

  final String? initialServerUrl;

  /// Overridable for tests; defaults to the provider or the OS secure store.
  final SavedCredentialsStore? credentials;

  final ServerUrlPolicy urlPolicy;

  /// A one-line message shown above the form, e.g. after a forced sign-out.
  final String? notice;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _serverUrl;
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _serverFocus = FocusNode();
  late final SavedCredentialsStore _store;
  bool _obscurePassword = true;
  bool _remember = false;
  bool _busy = false;
  String? _error;
  String? _serverError;
  String? _boundServer;

  /// `account_security.recovery_status.available` of the selected server. The
  /// forgot-password link is shown only while this is true.
  bool _recoveryAvailable = false;

  /// The username / password currently in the fields came from this device's
  /// memory, not from the user, so they follow the selected server.
  bool _usernameFromStore = false;
  bool _passwordFromStore = false;

  @override
  void initState() {
    super.initState();
    _store = widget.credentials ??
        _tryRead<SavedCredentialsStore>(context) ??
        SavedCredentialsStore();
    String? initial = widget.initialServerUrl;
    if (initial == null || initial.trim().isEmpty) {
      final client = _tryRead<FrappeApiClient>(context);
      if (client is FrappeClient && client.serverIdentity.trim().isNotEmpty) {
        initial = client.serverIdentity;
      }
    }
    _serverUrl = TextEditingController(
        text: initial?.trim().isNotEmpty == true ? initial! : '');
    _serverFocus.addListener(() {
      if (!_serverFocus.hasFocus) _bindToServer();
    });
    _restore();
  }

  Future<void> _restore() async {
    if (widget.initialServerUrl == null) {
      final client = _tryRead<FrappeApiClient>(context);
      String? saved;
      try {
        if (client is FrappeClient) saved = await client.getRememberedServer();
      } catch (_) {}
      saved ??= await _store.lastServer();
      if (saved != null &&
          saved.trim().isNotEmpty &&
          mounted &&
          _serverUrl.text.trim().isEmpty) {
        setState(() => _serverUrl.text = saved!.trim());
      }
    }
    await _bindToServer(force: true);
  }

  /// Loads the last username and, when the user opted in, the saved password
  /// for the server in the field. Never overwrites what the user typed.
  Future<void> _bindToServer({bool force = false}) async {
    final check = widget.urlPolicy.check(_serverUrl.text);
    if (!check.isValid) return;
    final server = check.url!;
    if (!force && server == _boundServer) return;
    _boundServer = server;
    unawaited(_checkRecovery(server));
    if (_usernameFromStore || _username.text.isEmpty) {
      final name = await _store.lastUsername(server);
      if (!mounted || server != _boundServer) return;
      setState(() {
        _username.text = name ?? '';
        _usernameFromStore = name != null;
        if (_passwordFromStore) _password.clear();
        _passwordFromStore = false;
      });
    }
    await _loadSavedPassword();
  }

  Future<void> _checkRecovery(String server) async {
    final accounts = _tryRead<AccountRepository>(context);
    if (accounts == null) return;
    if (_recoveryAvailable) setState(() => _recoveryAvailable = false);
    var available = false;
    try {
      final client = _tryRead<FrappeApiClient>(context);
      if (client is FrappeClient) await client.useServer(server);
      available = await accounts.recoveryStatus();
    } catch (_) {
      available = false;
    }
    if (mounted && server == _boundServer) {
      setState(() => _recoveryAvailable = available);
    }
  }

  Future<void> _loadSavedPassword() async {
    final server = _boundServer;
    final name = _username.text.trim();
    if (server == null || name.isEmpty) return;
    final saved = await _store.readPassword(server, name);
    if (!mounted || server != _boundServer || name != _username.text.trim()) {
      return;
    }
    setState(() {
      _remember = saved != null;
      if (saved != null && (_password.text.isEmpty || _passwordFromStore)) {
        _password.text = saved;
        _passwordFromStore = true;
      } else if (saved == null && _passwordFromStore) {
        _password.clear();
        _passwordFromStore = false;
      }
    });
  }

  Future<void> _toggleRemember(bool value) async {
    setState(() => _remember = value);
    if (value) return;
    // Turning the box off is an explicit request to stop keeping the password.
    final server = _boundServer;
    final name = _username.text.trim();
    if (server != null && name.isNotEmpty) {
      await _store.deletePassword(server, name);
    }
    if (mounted && _passwordFromStore) {
      setState(() {
        _password.clear();
        _passwordFromStore = false;
      });
    }
  }

  Future<void> _clearSaved() async {
    final server = _boundServer;
    final name = _username.text.trim();
    if (server == null) return;
    await _store.deletePassword(server, name);
    await _store.forgetUsername(server);
    if (!mounted) return;
    setState(() {
      _username.clear();
      _password.clear();
      _remember = false;
      _usernameFromStore = false;
      _passwordFromStore = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات ورود ذخیره‌شده پاک شد.')));
  }

  Future<void> _login({bool resetSetup = false}) async {
    if (_busy) return;
    final check = widget.urlPolicy.check(_serverUrl.text);
    if (!check.isValid) {
      setState(() {
        _serverError = check.error;
        _error = null;
      });
      return;
    }
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() {
        _serverError = null;
        _error = 'نام کاربری و رمز عبور را وارد کنید.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _serverError = null;
    });
    final server = check.url!;
    final username = _username.text.trim();
    final fromStore = _passwordFromStore;
    try {
      final client = context.read<FrappeApiClient>();
      final auth = context.read<AuthRepository>();
      if (client is FrappeClient) {
        await client.useServer(server);
        _serverUrl.text = client.serverIdentity;
      }
      await auth.signIn(username: username, password: _password.text);
      var note = '';
      if (_store.canStorePassword) {
        if (_remember) {
          final saved =
              await _store.savePassword(server, username, _password.text);
          if (!saved) note = 'ذخیره امن رمز روی این دستگاه ممکن نشد.';
        } else {
          await _store.deletePassword(server, username);
        }
      }
      await _store.rememberServer(server);
      await _store.rememberUsername(server, username);
      // On the web the browser's password manager offers to keep the password.
      TextInput.finishAutofillContext(shouldSave: _remember);
      _password.clear();
      if (!mounted) return;
      if (note.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
      }
      if (resetSetup) {
        final reset = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SetupResetPage()));
        var notice = reset == true
            ? 'بازنشانی سرور تأیید شد؛ با همان نام کاربری و رمز از ابتدا وارد شوید.' : null;
        try {
          await auth.signOut();
        } catch (_) {
          notice = '${notice ?? 'از بخش بازنشانی خارج شدید.'} خروج سروری تأیید نشد؛ دوباره وارد شوید.';
        }
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) =>
              LoginPage(initialServerUrl: server, notice: notice)), (_) => false);
        }
      } else {
        await _afterLogin();
      }
    } catch (error) {
      if (error is ApiException &&
          error.kind == ApiFailureKind.invalidCredentials &&
          fromStore) {
        // A remembered password the server no longer accepts is useless and
        // must not linger on the device.
        await _store.deletePassword(server, username);
        if (mounted) {
          setState(() {
            _password.clear();
            _passwordFromStore = false;
            _remember = false;
          });
        }
      }
      if (mounted) {
        setState(() => _error = error is FormatException
            ? 'نشانی سرور را درست وارد کنید؛ مثل https://erp.example.com'
            : error is ApiException
                ? (fromStore &&
                        error.kind == ApiFailureKind.invalidCredentials
                    ? 'رمز ذخیره‌شده دیگر معتبر نیست؛ رمز عبور تازه را وارد کنید.'
                    : error.message)
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
    await DemoChoiceStore.setDemoChosen(false);
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
      MaterialPageRoute<void>(builder: (_) => const PostLoginPage()),
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
    // The transfer service derives a stable id from the preview row, so a
    // second tap on the same row is an idempotent replay, not a new request.
    final requestId = '${data['request_id'] ?? ''}';
    await GenericRequestRepository(client, company).create(
        {...payload, 'company': company},
        requestId.isEmpty ? GenericRequestRepository.requestId() : requestId);
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

  Future<void> _openForgotPassword() async {
    final check = widget.urlPolicy.check(_serverUrl.text);
    if (!check.isValid) {
      setState(() => _serverError = check.error);
      return;
    }
    final client = context.read<FrappeApiClient>();
    final accounts = context.read<AccountRepository>();
    if (client is FrappeClient) await client.useServer(check.url!);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
            repository: accounts, initialIdentifier: _username.text.trim())));
  }

  Future<void> _openActivation() async {
    final check = widget.urlPolicy.check(_serverUrl.text);
    if (!check.isValid) {
      setState(() => _serverError = check.error);
      return;
    }
    final client = context.read<FrappeApiClient>();
    final accounts = context.read<AccountRepository>();
    if (client is FrappeClient) await client.useServer(check.url!);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: ActivateAccountPage(
                repository: accounts,
                initialIdentifier: _username.text.trim()))));
  }

  @override
  void dispose() {
    _serverUrl.dispose();
    _username.dispose();
    _password.dispose();
    _serverFocus.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label,
          {String? hint, Widget? prefix, Widget? suffix, String? error}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        errorText: error,
        errorMaxLines: 3,
        prefixIcon: prefix,
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    final canRecover =
        _recoveryAvailable && _tryRead<AccountRepository>(context) != null;
    final hasSaved = _remember && _store.canStorePassword;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const AsoudIconBox(
                                icon: Icons.account_balance_rounded,
                                color: AsoudColors.primary,
                                size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('آسود ERP',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: AsoudColors.primary)),
                                    const SizedBox(height: 2),
                                    Text(
                                        widget.notice ??
                                            'ورود به حساب کاربری سازمان',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AsoudColors.muted)),
                                  ]),
                            ),
                          ]),
                          const SizedBox(height: 18),
                          TextField(
                            key: const Key('server_field'),
                            controller: _serverUrl,
                            focusNode: _serverFocus,
                            enabled: !_busy,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            textDirection: TextDirection.ltr,
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: (_) {
                              if (_serverError != null) {
                                setState(() => _serverError = null);
                              }
                            },
                            decoration: _decoration('نشانی سرور',
                                hint: 'https://آدرس-سرور',
                                prefix: const Icon(Icons.cloud_outlined),
                                error: _serverError),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _username,
                            key: const Key('username_field'),
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            textDirection: TextDirection.ltr,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.username],
                            onChanged: (_) {
                              _usernameFromStore = false;
                              _loadSavedPassword();
                            },
                            decoration: _decoration('نام کاربری یا ایمیل',
                                prefix:
                                    const Icon(Icons.person_outline_rounded),
                                suffix: ListenableBuilder(
                                    listenable: _username,
                                    builder: (_, __) => _username.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : IconButton(
                                            key: const Key('clear_username'),
                                            tooltip: 'پاک کردن نام کاربری',
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20),
                                            onPressed: _busy
                                                ? null
                                                : () => setState(() {
                                                      _username.clear();
                                                      _usernameFromStore =
                                                          false;
                                                      if (_passwordFromStore) {
                                                        _password.clear();
                                                        _passwordFromStore =
                                                            false;
                                                      }
                                                      _remember = false;
                                                    }),
                                          ))),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _password,
                            key: const Key('password_field'),
                            enabled: !_busy,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            textDirection: TextDirection.ltr,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.password],
                            onChanged: (_) => _passwordFromStore = false,
                            onSubmitted: (_) => _login(),
                            decoration: _decoration('رمز عبور',
                                prefix: const Icon(Icons.lock_outline_rounded),
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'نمایش رمز عبور'
                                      : 'پنهان‌کردن رمز عبور',
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                )),
                          ),
                          InkWell(
                            key: const Key('remember_password_row'),
                            onTap: _busy
                                ? null
                                : () => _toggleRemember(!_remember),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Checkbox(
                                  key: const Key('remember_password_checkbox'),
                                  value: _remember,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: _busy
                                      ? null
                                      : (value) =>
                                          _toggleRemember(value ?? false),
                                ),
                                const Expanded(
                                    child: Text(
                                        'ذخیره رمز عبور در این دستگاه',
                                        style: TextStyle(fontSize: 13))),
                                if (hasSaved)
                                  TextButton(
                                    key: const Key('clear_saved_credentials'),
                                    onPressed: _busy ? null : _clearSaved,
                                    style: TextButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6)),
                                    child: const Text('پاک‌کردن',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ]),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(_error!,
                                  key: const Key('login_error'),
                                  style: const TextStyle(
                                      color: AsoudColors.danger,
                                      fontSize: 12,
                                      height: 1.5)),
                            ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: const Key('login_button'),
                              onPressed: _busy ? null : _login,
                              child:
                                  Text(_busy ? 'در حال ورود…' : 'ورود به آسود'),
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('temporary_setup_reset'),
                            style: TextButton.styleFrom(foregroundColor: AsoudColors.danger),
                            onPressed: _busy ? null : () => _login(resetSetup: true),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('بازنشانی موقت اطلاعات سرور (فقط مدیر سیستم)',
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
                          if (canRecover)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                key: const Key('forgot_password_link'),
                                onPressed: _busy ? null : _openForgotPassword,
                                child: const Text(
                                    'رمز عبور خود را فراموش کرده‌اید؟',
                                    style: TextStyle(fontSize: 12.5)),
                              ),
                            ),
                          if (_tryRead<AccountRepository>(context) != null)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                key: const Key('activate_account_link'),
                                onPressed: _busy ? null : _openActivation,
                                child: const Text('کد دعوت‌نامه دارید؟ فعال‌سازی حساب',
                                    style: TextStyle(fontSize: 12.5)),
                              ),
                            ),
                          if (widget.showDemoButton)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton.icon(
                                onPressed: _busy ? null : _openDemo,
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 18),
                                label: const Text(
                                    'ورود به نسخه نمایشی (آفلاین)',
                                    style: TextStyle(fontSize: 12.5)),
                              ),
                            ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
