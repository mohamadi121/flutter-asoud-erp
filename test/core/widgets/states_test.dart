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

  testWidgets('پیام فارسی از پیش ساخته‌شده حفظ و متن خام فنی حذف می‌شود',
      (tester) async {
    await pump(
      tester,
      ErrorState(
        failure: 'حساب کاربری شما به پرسنل فعال متصل نیست.',
        onRetry: () {},
      ),
      390,
    );
    expect(find.text('حساب کاربری شما به پرسنل فعال متصل نیست.'),
        findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('خطای دسترسی به‌صورت رشته هم دکمه تلاش دوباره ندارد',
      (tester) async {
    await pump(
      tester,
      ErrorState(failure: forbiddenFailureMessage, onRetry: () {}),
      390,
    );
    expect(find.text(forbiddenFailureMessage), findsOneWidget);
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

  testWidgets('حالت‌های مشترک داخل فهرست هم بدون سرریز رندر می‌شوند',
      (tester) async {
    await pump(
      tester,
      ListView(children: [
        const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'موردی نیست',
            description: 'بعداً نمایش داده می‌شود.'),
        ErrorState(
            failure: const ApiException(
                kind: ApiFailureKind.network, message: 'offline'),
            onRetry: () {}),
      ]),
      320,
    );
    expect(find.text('موردی نیست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('رشته فارسی از قبل ساخته‌شده دست‌نخورده برمی‌گردد', () {
    expect(failureMessage('خطای خاص سرور'), 'خطای خاص سرور');
    expect(
        failureMessage(const ApiException(
            kind: ApiFailureKind.forbidden, message: 'x')),
        forbiddenFailureMessage);
    expect(failureIsForbidden(forbiddenFailureMessage), isTrue);
    expect(
        failureIsForbidden(
            const ApiException(kind: ApiFailureKind.forbidden, message: 'x')),
        isTrue);
    expect(failureIsForbidden(const ApiException(
        kind: ApiFailureKind.network, message: 'x')), isFalse);
    expect(failureCanRetry(forbiddenFailureMessage), isFalse);
    expect(failureCanRetry('خطای شبکه'), isTrue);
  });
}
