import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_links_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements PartyRepository {}

void main() {
  const profile = PartyProfile(
    id: 'P-1',
    company: 'شرکت',
    kind: PartyKind.individual,
    displayName: 'علی رضایی',
    roles: {PartyRole.customer},
  );

  Future<void> pump(WidgetTester tester, PartyRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: PartyLinksPage(profile: profile, repository: repository)));
    await tester.pumpAndSettle();
  }

  testWidgets('party links failure shows the Persian reason and retries',
      (tester) async {
    final repository = _Repository();
    when(() => repository.listDetails(search: any(named: 'search')))
        .thenThrow(
            const ApiException(kind: ApiFailureKind.network, message: 'x'));
    await pump(tester, repository);
    expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'تلاش دوباره');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => repository.listDetails(search: 'علی رضایی')).called(2);
  });

  testWidgets('empty party links offer the create-code action', (tester) async {
    final repository = _Repository();
    when(() => repository.listDetails(search: any(named: 'search')))
        .thenAnswer((_) async => []);
    await pump(tester, repository);
    expect(find.text('کد تفصیلی‌ای ثبت نشده است'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'افزودن کد جدید'), findsWidgets);
  });
}
