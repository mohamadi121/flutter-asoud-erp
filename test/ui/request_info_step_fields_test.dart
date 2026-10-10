import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_types_page.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline remote: the builder falls back to the in-memory preview repository,
/// exactly as it does on the emulator without a server.
class _OfflineRemote implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
      const ApiException(message: 'offline', kind: ApiFailureKind.network));
}

Widget _app(Widget page) => RepositoryProvider<WorkflowRepository>.value(
      value: PreviewFallbackWorkflowRepository(_OfflineRemote()),
      child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(textDirection: TextDirection.rtl, child: page)),
    );

Future<void> _openInfoStep(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(const RequestTypesPage(company: 'دفتر نمونه')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ایجاد نوع درخواست جدید').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'step 1 «اطلاعات کلی» uses the shared App fields at ${width.toInt()} px',
        (tester) async {
      await _openInfoStep(tester, width);

      expect(find.text('نام درخواست *'), findsOneWidget);
      expect(find.byType(AppTextField), findsNWidgets(3));
      expect(find.byType(AppSelectField), findsOneWidget);
      expect(find.byType(AppSwitchTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('step 1 shows the required message and submits a valid name',
      (tester) async {
    await _openInfoStep(tester, 390);

    await tester.tap(find.text('ادامه').last);
    await tester.pumpAndSettle();
    expect(find.text('نام درخواست حداقل ۳ حرف باشد.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'نام درخواست *'), 'درخواست خرید');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان کوتاه'), 'خرید کالا');
    await tester.tap(find.text('ادامه').last);
    await tester.pumpAndSettle();

    expect(find.text('ساخت فرم درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the category is chosen through the shared option sheet',
      (tester) async {
    await _openInfoStep(tester, 390);

    await tester.tap(find.byType(AppSelectField));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('option-Finance')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('option-Finance')));
    await tester.pumpAndSettle();

    // The chosen label replaces the hint in the field.
    expect(find.text('مالی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
