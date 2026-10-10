import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/request_types/presentation/cubit/request_type_builder_cubit.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_types_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements WorkflowRepository {}

WorkflowDefinition _definition(String id, String title) => WorkflowDefinition(
      id: id,
      code: id,
      title: title,
      targetDoctype: requestTargetDoctype,
      status: WorkflowDefinitionStatus.active,
      isLocked: false,
      version: 1,
      stepsCount: 1,
      modified: DateTime(2026, 1, 1),
    );

void main() {
  Future<void> pump(WidgetTester tester, WorkflowRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
      value: repository,
      child: const MaterialApp(home: RequestTypesPage(company: 'شرکت')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('request-type load failure shows the Persian reason and retries',
      (tester) async {
    final repository = _Repository();
    when(() => repository.getWorkflows(company: any(named: 'company')))
        .thenThrow(
            const ApiException(kind: ApiFailureKind.network, message: 'x'));
    await pump(tester, repository);
    expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'تلاش دوباره');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    when(() => repository.getWorkflows(company: any(named: 'company')))
        .thenAnswer((_) async => []);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    verify(() => repository.getWorkflows(company: 'شرکت')).called(2);
    expect(find.text('نوع درخواستی ثبت نشده است'), findsOneWidget);
  });

  testWidgets('empty request-type list explains how to create the first one',
      (tester) async {
    final repository = _Repository();
    when(() => repository.getWorkflows(company: any(named: 'company')))
        .thenAnswer((_) async => []);
    await pump(tester, repository);
    expect(find.text('نوع درخواستی ثبت نشده است'), findsOneWidget);
    expect(find.text('ایجاد نوع درخواست جدید'), findsWidgets);
  });

  testWidgets('no request type matches the search term', (tester) async {
    final repository = _Repository();
    when(() => repository.getWorkflows(company: any(named: 'company')))
        .thenAnswer((_) async => [_definition('w1', 'خرید کالا')]);
    await pump(tester, repository);
    await tester.enterText(find.byType(TextField), 'ناموجود');
    await tester.pumpAndSettle();
    expect(find.text('نتیجه‌ای پیدا نشد'), findsOneWidget);
    expect(find.text('پاک‌کردن جستجو'), findsOneWidget);
    await tester.tap(find.text('پاک‌کردن جستجو'));
    await tester.pumpAndSettle();
    expect(find.text('خرید کالا'), findsOneWidget);
  });
}
