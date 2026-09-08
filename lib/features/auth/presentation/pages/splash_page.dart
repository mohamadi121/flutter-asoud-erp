import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), _open);
  }

  Future<void> _open() async {
    if (!mounted) return;
    setState(() => _error = null);
    final client = context.read<FrappeApiClient>();
    try {
      final restored =
          client is FrappeClient ? await client.restoreSession() : false;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
            builder: (_) => restored
                ? const DashboardLandingPage()
                : AppConfig.offlineDemoMode
                    ? const DashboardLandingPage(offlinePreview: true)
                    : const LoginPage()),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'بازیابی نشست امن ممکن نشد؛ دوباره تلاش کنید.');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AsoudColors.primary,
        body: SafeArea(
          child: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 24)
                  ],
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: AsoudColors.primary, size: 45),
              ),
              const SizedBox(height: 20),
              const Text('ASOUD ERP',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8)),
              const SizedBox(height: 7),
              const Text('حسابداری یکپارچه برای کسب‌وکار شما',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 11)),
              const SizedBox(height: 54),
              if (_error != null)
                TextButton(
                    onPressed: _open,
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.white)))
              else
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.4),
                ),
            ]),
          ),
        ),
      );
}
