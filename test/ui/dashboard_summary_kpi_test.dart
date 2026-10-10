import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _company = 'شرکت نمونه آسود';

/// Real `get_home_summary` shape, copied from `asoud_erp/api/v1/dashboard.py`.
Map<String, dynamic> _homeData({
  Object? todayReceipts = 12450000,
  Object? todaySales = 8200000,
  Object? bankAndCash = const {
    'total': 456700000,
    'accounts': [
      {
        'account': '1310 - بانک ملی - SC',
        'account_name': 'بانک ملی',
        'account_type': 'Bank',
        'balance': 456700000,
      }
    ],
  },
}) =>
    {
      'company': _company,
      'date': '2026-10-10',
      'currency': 'IRR',
      'today_receipts': todayReceipts,
      'today_payments': 0,
      'today_sales': todaySales,
      'bank_and_cash': bankAndCash,
      'open_documents': {
        'unpaid_sales_invoices': 1,
        'unpaid_purchase_invoices': 0,
        'draft_sales_invoices': 4,
        'draft_payment_entries': 0,
        'draft_journal_entries': 0,
        'pending_material_requests': 1,
        'my_open_tasks': 0,
        'total': 6,
      },
    };

/// Real `get_system_summary` shape, copied from `asoud_erp/api/v1/dashboard.py`.
Map<String, dynamic> _systemData() => {
      'users': {
        'total': 20,
        'active': 14,
        'online': 3,
        'online_window_minutes': 15,
      },
      'storage': {
        'files_bytes': 40,
        'database_bytes': 28,
        'used_bytes': 68,
        'quota_bytes': 100,
      },
      'pending_workflow_tasks': 6,
      'errors_last_24h': 0,
      'sync': {
        'last_completed_on': '2026-10-10 09:30:00',
        'stuck_requests': 0,
      },
      'scheduler_enabled': true,
    };

Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
      'message': {
        'ok': true,
        'data': data,
        'meta': {'api_version': 'v1'},
      }
    };

class _SummaryClient extends Fake implements FrappeApiClient {
  _SummaryClient({
    this.home,
    this.system,
    this.homeError,
    this.systemError,
  });

  Map<String, dynamic>? home;
  Map<String, dynamic>? system;
  Object? homeError;
  Object? systemError;
  int homeCalls = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'Administrator',
        fullName: 'مدیر سیستم',
        roles: ['System Manager'],
        company: _company,
      );

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('get_home_summary')) {
      homeCalls++;
      if (homeError != null) {
        final error = homeError!;
        homeError = null;
        throw error;
      }
      return _envelope(home!);
    }
    if (method.endsWith('get_system_summary')) {
      if (systemError != null) throw systemError!;
      return _envelope(system!);
    }
    throw UnimplementedError(method);
  }
}

Office _office() => Office(
      name: _company,
      type: OfficeType.legal,
      fiscalYearStart: DateTime(2026),
      setupComplete: true,
    );

Widget _app(Widget page, FrappeApiClient client) => MaterialApp(
      theme: AsoudTheme.light,
      home: RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

Widget _home(FrappeApiClient client) => _app(
      DashboardPage(
        office: _office(),
        officeName: _company,
      ),
      client,
    );

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('home KPI cards render server figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _SummaryClient(home: _homeData());

      await tester.pumpWidget(_home(client));
      await tester.pumpAndSettle();

      expect(find.text('همگام‌سازی با ASOUD ERP موفق بود'), findsOneWidget);
      expect(find.text('۱۲٬۴۵۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۸٬۲۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۴۵۶٬۷۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۶ سند'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('system summary renders server figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _SummaryClient(system: _systemData());

      await tester.pumpWidget(
          _app(const SettingsDashboardContent(company: _company), client));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('خلاصه وضعیت سیستم'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('۱۴'), findsOneWidget);
      expect(find.text('۳'), findsOneWidget);
      expect(find.text('۶۸٪'), findsOneWidget);
      expect(find.text('۶'), findsOneWidget);
      expect(find.text('سالم'), findsOneWidget);
    });
  }

  testWidgets('a null figure is not rendered as a card', (tester) async {
    final client = _SummaryClient(
      home: _homeData(todayReceipts: null, bankAndCash: null),
    );

    await tester.pumpWidget(_home(client));
    await tester.pumpAndSettle();

    expect(find.text('دریافتی امروز'), findsNothing);
    expect(find.text('موجودی بانک'), findsNothing);
    expect(find.text('فروش امروز'), findsOneWidget);
    expect(find.text('۸٬۲۰۰٬۰۰۰ ریال'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('a failed home summary shows a retry that reloads the figures',
      (tester) async {
    final client = _SummaryClient(
      home: _homeData(),
      homeError: const ApiException(
        kind: ApiFailureKind.network,
        message: 'ارتباط برقرار نشد',
      ),
    );

    await tester.pumpWidget(_home(client));
    await tester.pumpAndSettle();

    expect(find.text('دریافت اطلاعات ناموفق بود'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(client.homeCalls, 1);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(client.homeCalls, 2);
    expect(find.text('۱۲٬۴۵۰٬۰۰۰ ریال'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });

  testWidgets('a forbidden system summary names the refusal without retry',
      (tester) async {
    final client = _SummaryClient(
      systemError: const ApiException(
        kind: ApiFailureKind.forbidden,
        message: 'forbidden',
        statusCode: 403,
      ),
    );

    await tester.pumpWidget(
        _app(const SettingsDashboardContent(company: _company), client));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('خلاصه وضعیت سیستم'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('دسترسی محدود است'), findsOneWidget);
    expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });
}
