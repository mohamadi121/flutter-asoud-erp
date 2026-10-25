import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/account_repository.dart';
import '../../data/saved_credentials_store.dart';
import 'change_password_page.dart';

/// بیشتر ← حساب کاربری ← امنیت حساب. «تغییر رمز عبور» opens the very same
/// screen and service as the first-login profile form.
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({this.credentials, super.key});
  final SavedCredentialsStore? credentials;

  Future<void> _clearSaved(BuildContext context) async {
    final client = context.read<FrappeApiClient>();
    final store = credentials ?? SavedCredentialsStore();
    final server = client is FrappeClient ? client.serverIdentity : null;
    if (server != null) {
      final name = await store.lastUsername(server);
      if (name != null) await store.deletePassword(server, name);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('رمز ذخیره‌شده این حساب از دستگاه پاک شد.')));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'امنیت حساب', subtitle: 'حساب کاربری'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                key: const Key('security_change_password'),
                leading: const AsoudIconBox(
                    icon: Icons.lock_reset_rounded,
                    color: AsoudColors.primary,
                    size: 38),
                title: const Text('تغییر رمز عبور'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: ChangePasswordPage(
                            repository: context.read<AccountRepository>())))),
              ),
            ),
            Card(
              child: ListTile(
                key: const Key('security_clear_saved'),
                leading: const AsoudIconBox(
                    icon: Icons.delete_outline_rounded,
                    color: AsoudColors.danger,
                    size: 38),
                title: const Text('پاک‌کردن رمز ذخیره‌شده روی این دستگاه'),
                onTap: () => _clearSaved(context),
              ),
            ),
          ]),
        ),
      );
}
