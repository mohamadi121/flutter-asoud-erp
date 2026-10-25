import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/account_repository.dart';
import '../../domain/entities/login_state.dart';
import '../../domain/identity_validators.dart';
import 'change_password_page.dart';

/// «مشخصات اولیه مدیر کل سیستم»: completes the identity of the existing
/// administrator account. It creates no account, role or personnel file.
/// No step bar and no bottom navigation, by design.
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage(
      {required this.repository,
      required this.profile,
      required this.onCompleted,
      this.onBack,
      super.key});
  final AccountRepository repository;
  final AccountProfile profile;

  /// Receives the refreshed server state after the real save succeeded.
  final void Function(BuildContext context, LoginState state) onCompleted;

  /// The back button when there is nothing to pop (the first-login flow).
  final VoidCallback? onBack;

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _mobile = TextEditingController(text: widget.profile.mobile);
  late final _national =
      TextEditingController(text: widget.profile.nationalId);
  late final _email = TextEditingController(text: widget.profile.email);
  bool _optionalOpen = false;
  bool _busy = false;
  bool _touched = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _mobile, _national, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _firstError => IdentityValidators.required(_first.text, 'نام');
  String? get _lastError =>
      IdentityValidators.required(_last.text, 'نام خانوادگی');
  String? get _mobileError => IdentityValidators.mobile(_mobile.text);
  String? get _nationalError => IdentityValidators.nationalId(_national.text);
  String? get _emailError => IdentityValidators.email(_email.text);
  bool get _valid =>
      _firstError == null &&
      _lastError == null &&
      _mobileError == null &&
      _nationalError == null &&
      _emailError == null;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _touched = true);
    if (!_valid) {
      if (_nationalError != null || _emailError != null) {
        setState(() => _optionalOpen = true);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveAdminProfile(
        firstName: _first.text,
        lastName: _last.text,
        mobile: IdentityValidators.normalizeMobile(_mobile.text)!,
        nationalId: toLatinDigits(_national.text.trim()),
        email: _email.text,
      );
      // The server decides what comes next; read the state it now reports.
      final state = await widget.repository.loginState();
      if (mounted) widget.onCompleted(context, state);
    } catch (e) {
      if (mounted) setState(() => _error = failureDetail(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() => Navigator.of(context).push(
      MaterialPageRoute<bool>(
          builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: ChangePasswordPage(repository: widget.repository))));

  String get _status => widget.profile.active ? 'فعال' : 'غیرفعال';

  String get _role => widget.profile.roleLabel.trim().isEmpty
      ? 'مدیر کل سیستم'
      : widget.profile.roleLabel.trim();

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _field(String label, TextEditingController c, String? error,
          {bool required = false,
          String? hint,
          TextInputType? type,
          TextDirection? direction,
          int? maxLength,
          Key? key,
          List<String>? hints,
          List<TextInputFormatter>? formatters}) =>
      TextField(
        key: key,
        controller: c,
        enabled: !_busy,
        keyboardType: type,
        textDirection: direction,
        maxLength: maxLength,
        autofillHints: hints,
        inputFormatters: formatters,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          counterText: '',
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          errorText: (_touched || c.text.isNotEmpty) ? error : null,
          errorMaxLines: 2,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(children: [
              const AsoudIconBox(
                  icon: Icons.grid_view_rounded,
                  color: AsoudColors.primary,
                  size: 40),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('آسود ERP',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('مشخصات اولیه مدیر کل سیستم',
                          style: TextStyle(
                              fontSize: 10.5, color: AsoudColors.muted)),
                    ]),
              ),
              IconButton.outlined(
                key: const Key('profile_back'),
                tooltip: 'بازگشت',
                onPressed: _busy
                    ? null
                    : () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          widget.onBack?.call();
                        }
                      },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              children: [
                const Text('تکمیل مشخصات مدیر کل سیستم',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('پس از ایجاد دفتر کار، اطلاعات خود را تکمیل کنید.',
                      style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                ),
                _card(Row(children: [
                  const AsoudIconBox(
                      icon: Icons.verified_user_outlined,
                      color: AsoudColors.purple,
                      size: 38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.username,
                              key: const Key('account_username'),
                              textDirection: TextDirection.ltr,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          Text('حساب موجود · $_role · وضعیت: $_status',
                              key: const Key('account_role'),
                              style: const TextStyle(
                                  fontSize: 11, color: AsoudColors.muted)),
                        ]),
                  ),
                  TextButton(
                    key: const Key('change_password_button'),
                    onPressed: _busy ? null : _changePassword,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('تغییر رمز عبور ‹',
                        style: TextStyle(fontSize: 12)),
                  ),
                ])),
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [
                        AsoudIconBox(
                            icon: Icons.person_rounded,
                            color: AsoudColors.primary,
                            size: 30),
                        SizedBox(width: 8),
                        Text('اطلاعات ضروری',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _field('نام', _first, _firstError,
                                    required: true,
                                    key: const Key('first_name'),
                                    hints: const [AutofillHints.givenName])),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _field(
                                    'نام خانوادگی', _last, _lastError,
                                    required: true,
                                    key: const Key('last_name'),
                                    hints: const [AutofillHints.familyName])),
                          ]),
                      const SizedBox(height: 14),
                      _field('شماره موبایل', _mobile, _mobileError,
                          required: true,
                          hint: '۰۹۱۲۳۴۵۶۷۸۹',
                          type: TextInputType.phone,
                          direction: TextDirection.ltr,
                          key: const Key('mobile'),
                          hints: const [AutofillHints.telephoneNumber]),
                    ])),
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        key: const Key('optional_toggle'),
                        onTap: () =>
                            setState(() => _optionalOpen = !_optionalOpen),
                        child: Row(children: [
                          const AsoudIconBox(
                              icon: Icons.list_alt_rounded,
                              color: AsoudColors.warning,
                              size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              const TextSpan(children: [
                                TextSpan(
                                    text: 'اطلاعات تکمیلی',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800)),
                                TextSpan(
                                    text: ' (اختیاری)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AsoudColors.muted)),
                              ]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(_optionalOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                        ]),
                      ),
                      // Kept mounted while collapsed, so the typed values stay.
                      Offstage(
                        offstage: !_optionalOpen,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _field(
                                          'کد ملی', _national, _nationalError,
                                          hint: '۱۰ رقم',
                                          type: TextInputType.number,
                                          direction: TextDirection.ltr,
                                          maxLength: 10,
                                          key: const Key('national_id'))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _field('ایمیل', _email, _emailError,
                                          hint: 'name@email.com',
                                          type: TextInputType.emailAddress,
                                          direction: TextDirection.ltr,
                                          key: const Key('email'),
                                          hints: const [AutofillHints.email])),
                                ]),
                            const SizedBox(height: 8),
                            const Text(
                                'موبایل و ایمیل فقط پس از احراز مالکیت، تأییدشده محسوب می‌شوند.',
                                style: TextStyle(
                                    fontSize: 10.5, color: AsoudColors.muted)),
                          ]),
                        ),
                      ),
                    ])),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_error!,
                        key: const Key('profile_error'),
                        style: const TextStyle(color: AsoudColors.danger)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('profile_submit'),
                onPressed: _busy || !_valid ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('تأیید مشخصات و ورود به خانه'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
