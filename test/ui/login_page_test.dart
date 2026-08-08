import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_office_repository.dart';

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

  testWidgets('ادامه موقت ابتدا داشبورد خام را باز می‌کند', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<OfficeRepository>.value(
        value: FakeOfficeRepository(),
        child: MaterialApp(
          locale: const Locale('fa'),
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: LoginPage(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ادامه موقت بدون ورود'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز دفتری ایجاد نشده است'), findsOneWidget);
    expect(find.text('ایجاد دفتر کار'), findsOneWidget);
    expect(find.text('شخص حقیقی'), findsNothing);
  });
}
