import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements DetailGroupRepository {}

void main() {
  Future<void> pump(
      WidgetTester tester, DetailGroupRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepositoryProvider<DetailGroupRepository>.value(
      value: repository,
      child: const MaterialApp(home: DetailGroupsPage()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('detail-group failure shows the Persian reason and retries',
      (tester) async {
    final repository = _Repository();
    when(() => repository.getGroups()).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));
    await pump(tester, repository);
    expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'تلاش دوباره');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => repository.getGroups()).called(2);
  });

  testWidgets('empty detail-group list offers the create action',
      (tester) async {
    final repository = _Repository();
    when(() => repository.getGroups()).thenAnswer((_) async => []);
    await pump(tester, repository);
    expect(find.text('گروه تفصیلی شناوری ثبت نشده است'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'افزودن گروه'), findsWidgets);
  });
}
