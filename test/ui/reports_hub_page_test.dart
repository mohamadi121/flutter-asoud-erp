import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/states.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/reports/presentation/pages/ledger_page.dart';
import 'package:asoud_erp/features/reports/presentation/pages/reports_hub_page.dart';
import 'package:asoud_erp/features/reports/presentation/pages/trial_balance_page.dart';
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

const _administrator = FrappeUserContext(
  userId: 'admin@asoud-demo.local',
  fullName: 'مدیر سیستم',
  roles: ['Administrator', 'System Manager'],
);

const _hrManager = FrappeUserContext(
  userId: 'hr@asoud-demo.local',
  fullName: 'مدیر منابع انسانی',
  roles: ['HR Manager', 'Desk User'],
);

void main() {
  late _Client client;

  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'administrator sees the ledger and trial-balance cards and each opens its page at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      when(() => client.getCurrentUser())
          .thenAnswer((_) async => _administrator);

      await tester.pumpWidget(_app(const ReportsHubPage(), client));
      await tester.pumpAndSettle();

      expect(find.text('دفتر کل'), findsOneWidget);
      expect(find.text('تراز آزمایشی'), findsOneWidget);
      // Reports with no real page must not appear as dead cards.
      expect(find.text('مرور حساب‌ها'), findsNothing);
      expect(find.text('گزارش‌های مالی'), findsNothing);

      await tester.tap(find.text('دفتر کل'));
      await tester.pumpAndSettle();
      expect(find.byType(LedgerPage), findsOneWidget);
    });

    testWidgets('trial-balance card opens its page at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      when(() => client.getCurrentUser())
          .thenAnswer((_) async => _administrator);

      await tester.pumpWidget(_app(const ReportsHubPage(), client));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تراز آزمایشی'));
      await tester.pumpAndSettle();
      expect(find.byType(TrialBalancePage), findsOneWidget);
    });

    testWidgets(
        'hr-manager without accounting access sees the empty state at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      when(() => client.getCurrentUser()).thenAnswer((_) async => _hrManager);

      await tester.pumpWidget(_app(const ReportsHubPage(), client));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('دفتر کل'), findsNothing);
      expect(find.text('تراز آزمایشی'), findsNothing);
    });
  }

  testWidgets('offline preview keeps the coming-soon reports destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => client.isAuthenticated).thenReturn(false);

    await tester.pumpWidget(_app(
        const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true),
        client));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'عملیات'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'گزارش‌ها'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportsHubPage), findsNothing);
    expect(find.byType(ComingSoonState), findsOneWidget);
  });
}
