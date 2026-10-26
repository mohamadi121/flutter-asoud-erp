import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements OrganizationRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OrganizationSnapshot([], 0, false));
  });

  Future<void> pump(
      WidgetTester tester, OrganizationRepository repository, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.units(any()))
        .thenAnswer((_) async => {'units': <dynamic>[], 'can_manage': true});
    when(() => repository.employees(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(MaterialApp(
        home: OrganizationPage(company: 'شرکت', repository: repository)));
    await tester.pumpAndSettle();
  }

  testWidgets('organization load failure shows the Persian reason and retries',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load(any())).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));
    await pump(tester, repository);
    expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'تلاش دوباره');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => repository.load('شرکت')).called(2);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('empty organization chart explains how to add positions at $width',
        (tester) async {
      final repository = _Repository();
      when(() => repository.load(any()))
          .thenAnswer((_) async => const OrganizationSnapshot([], 0, false));
      await pump(tester, repository, width: width);
      expect(find.text('ایجاد ساختار سازمانی'), findsOneWidget);
      expect(find.text('مشاهده و تکمیل ساختار سازمانی'), findsNothing);
      await tester.tap(find.text('ایجاد ساختار دستی'));
      await tester.pumpAndSettle();
      expect(find.text('هنوز واحدی تعریف نشده است.'), findsOneWidget);
      final pageScroll = find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)).first;
      final addUnit = find.widgetWithText(FilledButton, 'افزودن واحد به پیش‌نویس');
      await tester.scrollUntilVisible(addUnit, 100, scrollable: pageScroll);
      expect(addUnit, findsOneWidget);
      final next = find.widgetWithText(FilledButton, 'ادامه: تعریف جایگاه‌های شغلی');
      await tester.scrollUntilVisible(next, 100, scrollable: pageScroll);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      // The positions step exists independently; a unit is still required before
      // saving a position. No old TabBarView or legacy button label is assumed.
      final positionsStep = find.widgetWithText(TextButton, '۲. جایگاه‌ها');
      // ensureVisible's default alignment can put this cached child behind the
      // fixed app bar at narrow widths. Restore the real top of the viewport.
      final position = tester.state<ScrollableState>(pageScroll).position;
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(positionsStep.hitTestable(), findsOneWidget);
      await tester.tap(positionsStep.hitTestable());
      await tester.pumpAndSettle();
      final addPosition = find.widgetWithText(FilledButton, 'افزودن جایگاه به پیش‌نویس');
      await tester.scrollUntilVisible(addPosition, 100, scrollable: pageScroll);
      expect(addPosition, findsOneWidget);
      expect(find.text('جایگاه بدون انتساب پرسنل ساخته می‌شود.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
