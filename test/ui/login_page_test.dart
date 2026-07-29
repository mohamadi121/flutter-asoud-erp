import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('صفحه ورود تا آماده‌شدن سرور غیرفعال است', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    ));

    expect(find.text('ورود تا آماده‌شدن سرور غیرفعال است'), findsOneWidget);
    expect(find.text('ادامه موقت بدون ورود'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
}
