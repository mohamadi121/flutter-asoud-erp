import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements PersonnelRepository {}

void main() {
  testWidgets(
      'خطای دریافت فهرست پرسنل به‌شکل خطا نمایش داده می‌شود نه فهرست خالی',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository();
    when(() => repository.list('office')).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));

    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: PersonnelPage(company: 'office', repository: repository))));
    await tester.pumpAndSettle();

    expect(
        find.text('دریافت اطلاعات ناموفق بود'),
        findsOneWidget,
        reason: 'خطا باید با عنوان خطا نمایش داده شود');
    expect(
        find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(
        find.text('پرسنلی با این مشخصات وجود ندارد.'),
        findsNothing,
        reason: 'خطا نباید به‌شکل فهرست خالی دیده شود');
    expect(tester.takeException(), isNull);
  });

  testWidgets('خطای دسترسی در فهرست پرسنل دکمهٔ تلاش دوباره ندارد',
      (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository();
    when(() => repository.list('office')).thenThrow(
        const ApiException(kind: ApiFailureKind.forbidden, message: '403'));

    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: PersonnelPage(company: 'office', repository: repository))));
    await tester.pumpAndSettle();

    expect(find.text('دسترسی محدود است'), findsOneWidget);
    expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
    expect(find.text('پرسنلی با این مشخصات وجود ندارد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
