import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/office_setup/data/demo/office_demo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

Widget _app(Widget page, _Client client) => MaterialApp(
      theme: AsoudTheme.light,
      home: RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.getCurrentUser()).thenThrow(Exception('offline'));
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('preview dashboard shows the demo office and figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final office = demoPreviewOffice();
      await tester.pumpWidget(_app(
          DashboardPage(
              office: office, officeName: office.name, offlinePreview: true),
          client));
      await tester.pumpAndSettle();

      expect(find.text('شرکت نمونه آسود'), findsWidgets);
      expect(find.text('۱۲٬۴۵۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۸٬۲۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۴۵۶٬۷۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۶ سند'), findsOneWidget);
      expect(find.text('استاندارد ایران'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('طرف حساب‌ها'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('طرف حساب‌ها'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('preview settings show demo system figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
          const SettingsDashboardContent(
              company: demoCompanyName, offlinePreview: true),
          client));
      await tester.pumpAndSettle();

      expect(find.text('کاربران فعال'), findsOneWidget);
      expect(find.text('۱۴'), findsOneWidget);
      expect(find.text('۶۸٪'), findsOneWidget);
      expect(find.text('نمایشی'), findsWidgets);
    });
  }
}
