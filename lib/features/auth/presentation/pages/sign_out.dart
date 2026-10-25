import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../domain/repositories/auth_repository.dart';
import 'login_page.dart';

/// Explicit sign-out: revokes the server session, then opens the login screen
/// with the last server (and the username it remembers). A password the user
/// chose to keep in the secure store is NOT deleted here.
Future<void> signOutToLogin(BuildContext context) => signOutWith(
    client: context.read<FrappeApiClient>(),
    auth: context.read<AuthRepository>(),
    navigator: Navigator.of(context));

/// Same as [signOutToLogin] for callers whose own context may be gone by the
/// time the user taps (a page that replaced itself).
Future<void> signOutWith({
  required FrappeApiClient client,
  required AuthRepository auth,
  required NavigatorState navigator,
}) async {
  final serverUrl = client is FrappeClient ? client.serverIdentity : null;
  String? notice;
  try {
    await auth.signOut();
  } catch (_) {
    // The local session is cleared by the client either way; tell the user
    // the server could not confirm the revocation.
    notice = 'خروج روی دستگاه انجام شد، اما باطل شدن نشست روی سرور تأیید نشد.';
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: LoginPage(initialServerUrl: serverUrl, notice: notice)),
    ),
    (_) => false,
  );
}
