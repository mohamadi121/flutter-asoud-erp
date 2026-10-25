import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../office_setup/presentation/pages/office_type_page.dart';
import '../../../../core/network/frappe_client.dart';
import '../../data/account_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/login_state.dart';
import '../../domain/login_router.dart';
import 'admin_profile_page.dart';
import 'change_password_page.dart';
import 'sign_out.dart';

/// Reads the server's login state once and opens the right screen:
/// forced password change → first office (administrator only) → administrator
/// profile → office choice → home. Without an [AccountRepository] (offline
/// preview and legacy tests) it opens the plain home.
class PostLoginPage extends StatefulWidget {
  const PostLoginPage({super.key});

  @override
  State<PostLoginPage> createState() => _PostLoginPageState();
}

class _PostLoginPageState extends State<PostLoginPage> {
  AccountRepository? _accounts;
  late final NavigatorState _nav;
  FrappeApiClient? _client;
  AuthRepository? _auth;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nav = Navigator.of(context);
    try {
      _accounts = context.read<AccountRepository>();
      _client = context.read<FrappeApiClient>();
      _auth = context.read<AuthRepository>();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final accounts = _accounts;
    if (accounts == null) {
      _openHome();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await accounts.loginState();
      if (!mounted) return;
      await _go(state);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = failureMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final client = _client, auth = _auth;
    if (client == null || auth == null) return;
    await signOutWith(client: client, auth: auth, navigator: _nav);
  }

  void _replace(Widget page) => _nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) =>
              Directionality(textDirection: TextDirection.rtl, child: page)),
      (_) => false);

  void _openHome() => _replace(const DashboardLandingPage());

  Future<void> _go(LoginState state) async {
    final route = decideLoginRoute(state);
    switch (route.step) {
      case LoginStep.accountDisabled:
        _replace(NoOfficeAccessView(
            message: route.message ??
                'حساب کاربری شما غیرفعال است. با مدیر سیستم تماس بگیرید.',
            onSignOut: () => _signOut()));
      case LoginStep.changePassword:
        _replace(ChangePasswordPage(
            repository: _accounts!,
            forced: true,
            onChanged: () => _replace(const PostLoginPage())));
      case LoginStep.createFirstOffice:
        _replace(OfficeTypePage(
            allowOfflinePreview: false,
            firstOffice: true,
            onCreated: (ctx, office) => _replace(const PostLoginPage())));
      case LoginStep.completeAdminProfile:
        var profile = state.profile;
        try {
          // Real stored identity (including the national id) of the admin.
          profile = await _accounts!.adminProfile();
        } catch (_) {}
        if (!mounted) return;
        _replace(AdminProfilePage(
            repository: _accounts!,
            profile: profile,
            onBack: () => _signOut(),
            onCompleted: (ctx, next) => _replace(const PostLoginPage())));
      case LoginStep.selectOffice:
        _replace(OfficePickerPage(
            offices: state.offices,
            onPicked: (office) async {
              await _accounts!.selectOffice(office.name);
              _openHome();
            },
            onSignOut: () => _signOut()));
      case LoginStep.noOfficeAccess:
        _replace(route.message == null
            ? NoOfficeAccessView(onSignOut: () => _signOut())
            : NoOfficeAccessView(
                message: route.message!, onSignOut: () => _signOut()));
      case LoginStep.home:
        if (route.office != state.selectedOffice) {
          try {
            await _accounts!.selectOffice(route.office!);
          } catch (_) {}
        }
        _openHome();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 44, color: AsoudColors.warning),
                          const SizedBox(height: 12),
                          Text(_error ?? '',
                              key: const Key('post_login_error'),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton(
                              onPressed: _load,
                              child: const Text('تلاش دوباره')),
                          TextButton(
                              onPressed: () => _signOut(),
                              child: const Text('خروج از حساب')),
                        ]),
                  ),
          ),
        ),
      );
}

/// The message for an account that may sign in but has no office. It offers
/// no way to create an office or to see any data.
class NoOfficeAccessView extends StatelessWidget {
  const NoOfficeAccessView(
      {this.message = 'هنوز دسترسی به دفتر کاری برای شما تعیین نشده است.',
      required this.onSignOut,
      super.key});
  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 48, color: AsoudColors.warning),
                const SizedBox(height: 16),
                Text(message,
                    key: const Key('no_office_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, height: 1.8)),
                const SizedBox(height: 8),
                const Text('پس از تعیین دسترسی توسط مدیر، دوباره وارد شوید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AsoudColors.muted)),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('خروج از حساب')),
              ]),
            ),
          ),
        ),
      );
}

/// Lets a multi-office account choose among its permitted offices only.
class OfficePickerPage extends StatelessWidget {
  const OfficePickerPage(
      {required this.offices,
      required this.onPicked,
      required this.onSignOut,
      super.key});
  final List<OfficeRef> offices;
  final Future<void> Function(OfficeRef office) onPicked;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('انتخاب دفتر کار',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('دفتری را که می‌خواهید با آن کار کنید انتخاب کنید.',
                style: TextStyle(color: AsoudColors.muted)),
            const SizedBox(height: 12),
            for (final office in offices)
              Card(
                child: ListTile(
                  key: Key('office_${office.name}'),
                  leading: const Icon(Icons.business_rounded),
                  title: Text(office.title),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => onPicked(office),
                ),
              ),
            TextButton(
                onPressed: onSignOut, child: const Text('خروج از حساب')),
          ]),
        ),
      );
}
