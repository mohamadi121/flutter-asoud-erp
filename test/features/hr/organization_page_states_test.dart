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
      WidgetTester tester, OrganizationRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.units(any()))
        .thenAnswer((_) async => {'units': <dynamic>[], 'can_manage': true});
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

  testWidgets('empty organization chart explains how to add positions',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load(any()))
        .thenAnswer((_) async => const OrganizationSnapshot([], 0, false));
    await pump(tester, repository);
    expect(find.text('ایجاد ساختار سازمانی'), findsOneWidget);
    expect(find.text('مشاهده و تکمیل ساختار سازمانی'), findsNothing);
    await tester.tap(find.text('ایجاد ساختار دستی'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز واحدی تعریف نشده است.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('افزودن واحد'), 200,
        scrollable: find
            .descendant(
                of: find.byType(TabBarView), matching: find.byType(Scrollable))
            .last);
    expect(find.text('افزودن واحد'), findsOneWidget);
    expect(find.text('افزودن جایگاه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
