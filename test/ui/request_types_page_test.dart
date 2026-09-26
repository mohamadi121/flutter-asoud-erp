import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_types_page.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineRemote implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
      const ApiException(message: 'offline', kind: ApiFailureKind.network));
}

Widget app(Widget page) => RepositoryProvider<WorkflowRepository>.value(
      value: PreviewFallbackWorkflowRepository(_OfflineRemote()),
      child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(textDirection: TextDirection.rtl, child: page)),
    );

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings quick action opens request types', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(
        const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true)));
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tapText(tester, 'انواع درخواست');
    expect(find.byType(RequestTypesPage), findsOneWidget);
    expect(find.text('هنوز نوع درخواستی تعریف نشده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('builds a request type in four steps at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(app(const RequestTypesPage(company: 'دفتر نمونه')));
      await tester.pumpAndSettle();

      await tapText(tester, 'ایجاد نوع درخواست جدید');
      expect(find.text('ایجاد نوع درخواست جدید'), findsOneWidget);
      await tapText(tester, 'ادامه');
      expect(find.text('نام درخواست حداقل ۳ حرف باشد.'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'نام درخواست *'), 'درخواست خرید');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'عنوان کوتاه'), 'خرید کالا');
      await tapText(tester, 'ادامه');
      expect(find.text('ساخت فرم درخواست'), findsOneWidget);
      expect(find.text('شماره درخواست'), findsOneWidget);

      await tapText(tester, 'افزودن فیلد جدید');
      await tapText(tester, 'انتخابی');
      expect(find.text('افزودن فیلد'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'عنوان فیلد *'), 'نوع خرید');
      await tester.enterText(find.widgetWithText(TextField, 'گزینه 1'), 'کالا');
      await tapText(tester, 'ذخیره');
      expect(find.text('حداقل دو گزینه غیرتکراری وارد کنید.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'گزینه 2'), 'خدمت');
      await tapText(tester, 'ذخیره');
      expect(find.text('نوع خرید'), findsOneWidget);
      expect(find.text('اختیاری'), findsOneWidget);

      await tapText(tester, 'ادامه');
      expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);
      expect(find.text('نوع خرید'), findsOneWidget);
      await tapText(tester, 'ادامه');
      expect(find.text('دسترسی ثبت درخواست'), findsOneWidget);
      await tapText(tester, 'کارشناس');
      await tapText(tester, 'ذخیره و پایان');

      expect(find.byType(RequestTypesPage), findsOneWidget);
      expect(find.text('درخواست خرید'), findsOneWidget);
      expect(find.text('خرید کالا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
