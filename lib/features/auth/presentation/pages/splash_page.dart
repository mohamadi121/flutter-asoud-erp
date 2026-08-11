import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    });
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
