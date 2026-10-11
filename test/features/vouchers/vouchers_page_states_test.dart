import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/vouchers/domain/repositories/vouchers_repository.dart';
import 'package:asoud_erp/features/vouchers/presentation/pages/vouchers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements VouchersRepository {}

void main() {
  Future<void> pump(WidgetTester tester, VouchersRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(home: VouchersPage(repository: repository)));
    await tester.pumpAndSettle();
  }

  Future<void> request(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'دفتر مرکزی');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('empty voucher list explains how to load documents',
      (tester) async {
    await pump(tester, _Repository());
    expect(find.text('سند حسابداری‌ای برای نمایش نیست'), findsOneWidget);
    expect(
        find.text(
            'برای دیدن اسناد، نام دفتر را وارد کنید و دکمه دریافت را بزنید.'),
        findsOneWidget);
  });

  testWidgets('voucher load failure shows the Persian reason and retries',
      (tester) async {
    final repository = _Repository();
    when(() => repository.getVouchers(any())).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));
    await pump(tester, repository);
    await request(tester);
    expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'تلاش دوباره');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => repository.getVouchers('دفتر مرکزی')).called(2);
  });

  testWidgets('forbidden voucher load has no retry button', (tester) async {
    final repository = _Repository();
    when(() => repository.getVouchers(any())).thenThrow(
        const ApiException(kind: ApiFailureKind.forbidden, message: 'no'));
    await pump(tester, repository);
    await request(tester);
    expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });
}
