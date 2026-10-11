import 'package:flutter/material.dart';

/// Full-screen «دسترسی ندارید» state for a manager screen opened by a role
/// without access, so a deep link never lands on a blank or failing page.
class AccessDeniedScaffold extends StatelessWidget {
  const AccessDeniedScaffold({
    this.title = 'دسترسی ندارید',
    this.message = 'نقش کاربری شما اجازهٔ ورود به این بخش را ندارد.',
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 14),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, height: 1.7)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('بازگشت'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
