import 'entities/login_state.dart';

/// Where an authenticated account goes next (spec sections 12, 13 and 25).
enum LoginStep {
  accountDisabled,
  changePassword,
  createFirstOffice,
  completeAdminProfile,
  selectOffice,
  noOfficeAccess,
  home,
}

class LoginRoute {
  const LoginRoute(this.step, {this.office, this.message});

  final LoginStep step;

  /// The server's Persian sentence for [LoginStep.accountDisabled] and
  /// [LoginStep.noOfficeAccess], when it sent one.
  final String? message;

  /// The office the home screen opens for [LoginStep.home].
  final String? office;

  @override
  bool operator ==(Object other) =>
      other is LoginRoute && other.step == step && other.office == office;

  @override
  int get hashCode => Object.hash(step, office);

  @override
  String toString() => 'LoginRoute($step, $office)';
}

/// The screen after sign-in. The server decides (`login_state.next.route`);
/// the app only maps that answer to a step and never second-guesses it:
///
/// `account-disabled`, `change-password`, `create-first-office`,
/// `complete-admin-profile`, `office-select`, `home` (with `next.office`),
/// `no-office` (with `next.message`).
///
/// An unknown route is treated as «no office» so that nothing sensitive opens.
/// A state without `next` (hand-built previews only) uses [_localRoute], the
/// same rule the backend applies.
LoginRoute decideLoginRoute(LoginState state) {
  final next = state.next;
  if (next == null) return _localRoute(state);
  switch (next.route) {
    case 'account-disabled':
      return LoginRoute(LoginStep.accountDisabled, message: next.message);
    case 'change-password':
      return const LoginRoute(LoginStep.changePassword);
    case 'create-first-office':
      return const LoginRoute(LoginStep.createFirstOffice);
    case 'complete-admin-profile':
      return const LoginRoute(LoginStep.completeAdminProfile);
    case 'office-select':
      return const LoginRoute(LoginStep.selectOffice);
    case 'home':
      final office = next.office ?? state.selectedOffice;
      if (office == null || office.isEmpty) {
        return const LoginRoute(LoginStep.selectOffice);
      }
      return LoginRoute(LoginStep.home, office: office);
    default:
      return LoginRoute(LoginStep.noOfficeAccess, message: next.message);
  }
}

LoginRoute _localRoute(LoginState state) {
  if (!state.accountActive) return const LoginRoute(LoginStep.accountDisabled);
  if (state.mustChangePassword || state.temporaryPasswordExpired) {
    return const LoginRoute(LoginStep.changePassword);
  }
  final hasOffice = state.offices.isNotEmpty;
  if (state.isSystemAdmin) {
    if (!state.firstOfficeExists && !hasOffice) {
      return const LoginRoute(LoginStep.createFirstOffice);
    }
    if (!state.adminProfileComplete) {
      return const LoginRoute(LoginStep.completeAdminProfile);
    }
  }
  if (!hasOffice) return const LoginRoute(LoginStep.noOfficeAccess);
  if (state.offices.length == 1) {
    return LoginRoute(LoginStep.home, office: state.offices.single.name);
  }
  final selected = state.selectedOffice;
  if (selected != null && state.offices.any((o) => o.name == selected)) {
    return LoginRoute(LoginStep.home, office: selected);
  }
  return const LoginRoute(LoginStep.selectOffice);
}
