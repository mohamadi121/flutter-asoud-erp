import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/core/widgets/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, double width) async {
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
          textDirection: TextDirection.rtl, child: Scaffold(body: child)),
    ));
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'حالت‌های مشترک در عرض $width پیکسل RTL بدون سرریز نمایش داده می‌شوند',
        (tester) async {
      await pump(
        tester,
        ErrorState(
          failure: const ApiException(
              kind: ApiFailureKind.network, message: 'offline'),
          onRetry: () {},
        ),
        width,
      );
      expect(
          find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
          findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pump(
          tester,
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'موردی برای نمایش نیست',
            description: 'پس از ثبت، موارد اینجا نمایش داده می‌شوند.',
          ),
          width);
      expect(find.text('موردی برای نمایش نیست'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pump(
          tester,
          const ComingSoonState(
            description: 'این بخش در نسخه‌های بعدی در دسترس خواهد بود.',
          ),
          width);
      expect(find.text('به‌زودی'), findsOneWidget);
      expect(find.text('بازگشت'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('خطای دسترسی دکمه تلاش دوباره ندارد', (tester) async {
    await pump(
      tester,
      const ErrorState.forbidden(),
      390,
    );
    expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });

  test('پیام شکست برای گونه‌های API فارسی و مشخص است', () {
    expect(
        failureMessage(const ApiException(
            kind: ApiFailureKind.unauthenticated, message: 'x')),
        'نشست شما پایان یافته است. دوباره وارد شوید.');
    expect(
        failureMessage(
            const ApiException(kind: ApiFailureKind.forbidden, message: 'x')),
        'اجازه دسترسی به این بخش را ندارید');
    expect(
        failureMessage(
            const ApiException(kind: ApiFailureKind.validation, message: 'x')),
        'اطلاعات واردشده را بررسی کنید.');
  });
}
