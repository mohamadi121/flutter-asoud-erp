import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFrappeClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) async =>
      const [];
}

void main() {
  group('Dashboard Quick Actions Persian Localization (Bug #12)', () {
    testWidgets(
        'quick actions show Persian subtitles and no English leaks at 320 and 390 px',
        (tester) async {
      final widths = [320.0, 390.0];
      for (final width in widths) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final client = _FakeFrappeClient();
        await tester.pumpWidget(
          RepositoryProvider<FrappeApiClient>.value(
            value: client,
            child: MaterialApp(
              theme: AsoudTheme.light,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: DashboardPage(officeName: 'شرکت نمونه'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to quick actions
        final target = find.text('دریافت و پرداخت');
        await tester.dragUntilVisible(
          target,
          find.byType(Scrollable).first,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        // Must NOT find English subtitles
        expect(find.text('Payment'), findsNothing);
        expect(find.text('Sale Invoice'), findsNothing);
        expect(find.text('Workflow Request'), findsNothing);
        expect(find.text('Journal Entry'), findsNothing);
        expect(find.text('Document'), findsNothing);
        expect(find.text('Customer/Supplier'), findsNothing);

        // Concrete Persian subtitles
        expect(find.text('نقد و بانک'), findsOneWidget);
        expect(find.text('صدور و پیگیری'), findsOneWidget);
        expect(find.text('گردش کار و فرم‌ها'), findsOneWidget);
        expect(find.text('اسناد مالی'), findsOneWidget);
        expect(find.text('الگوهای آماده'), findsOneWidget);
        expect(find.text('مشتریان و تأمین‌کنندگان'), findsOneWidget);
      }
    });
  });
}
