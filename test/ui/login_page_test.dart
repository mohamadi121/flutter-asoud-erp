import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_office_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('صفحه ورود همیشه فعال است و نسخه نمایشی را پیشنهاد می‌دهد',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(showDemoButton: true),
      ),
    ));

    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('نام کاربری یا ایمیل'), findsOneWidget);
    expect(find.text('ورود به نسخه نمایشی (آفلاین)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('پرچم نمایشی فقط دکمه نسخه نمایشی را کنترل می‌کند',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(showDemoButton: false),
      ),
    ));

    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('ورود به نسخه نمایشی (آفلاین)'), findsNothing);
  });

  testWidgets('ادامه موقت ابتدا داشبورد خام را باز می‌کند', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<OfficeRepository>.value(
        value: FakeOfficeRepository(),
        child: MaterialApp(
          locale: const Locale('fa'),
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: LoginPage(showDemoButton: true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ورود به نسخه نمایشی (آفلاین)'));
    await tester.pumpAndSettle();
    expect(find.text('بیایید دفتر کار شما\nرا برای اولین بار راه‌اندازی کنیم'),
        findsOneWidget);
    expect(find.text('شروع ایجاد دفتر'), findsOneWidget);
    expect(find.text('شخص حقیقی'), findsNothing);
  });
}
