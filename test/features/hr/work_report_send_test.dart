import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

class _Hr extends Fake implements HrRepository {
  _Hr({this.fail = false});
  final bool fail;
  @override
  Future<List<WorkReport>> reports() async {
    if (fail) {
      throw const ApiException(
          kind: ApiFailureKind.validation,
          message: 'پرسنل فعال به این حساب متصل نیست.');
    }
    return [
      WorkReport(
          id: 'WR-1',
          date: DateTime(2026, 10, 20),
          activities: const [WorkActivity(title: 'پیگیری', durationMinutes: 30)]),
      // The real `hr.list_reports` rows carry no activities: nothing to send.
      WorkReport(id: 'WR-2', date: DateTime(2026, 10, 21)),
    ];
  }
}

Widget _app(_Client client, HrRepository hr) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<HrRepository>.value(value: hr),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: const Directionality(
            textDirection: TextDirection.rtl,
            child: WorkReportsPage(company: 'شرکت نمونه آسود')),
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'u', fullName: 'مدیر', roles: ['System Manager']));
  });

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {
        'message': {'ok': true, 'data': data, 'meta': {'api_version': 'v1'}}
      };

  testWidgets(
      'send uses hr.save_report with status Submitted (there is no submit_report)',
      (tester) async {
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => envelope({
              'name': 'WR-1',
              'status': 'Submitted',
              'report_date': '2026-10-20',
              'total_minutes': 30,
              'review': {
                'route': 'direct_manager',
                'superior': 'HR-EMP-1',
                'superior_name': 'خانم رضایی',
                'note': null,
              },
            }));
    await tester.pumpWidget(_app(client, _Hr()));
    await tester.pumpAndSettle();
    // only the report whose activities are known offers the send button
    expect(find.byKey(const Key('send_report_WR-2')), findsNothing);
    await tester.tap(find.byKey(const Key('send_report_WR-1')));
    await tester.pumpAndSettle();
    final captured = verify(() => client.callMethod(
        'asoud_erp.api.v1.hr.save_report',
        data: captureAny(named: 'data'))).captured.single as Map;
    final payload = captured['payload'] as Map;
    expect(payload['name'], 'WR-1');
    expect(payload['status'], 'Submitted');
    expect((payload['activities'] as List).single['title'], 'پیگیری');
    verifyNever(() => client.callAsoudMethod(any(), data: any(named: 'data')));
    expect(find.text('گزارش برای خانم رضایی ارسال شد.'), findsOneWidget);
  });

  testWidgets('with no direct superior the managers pool note is shown',
      (tester) async {
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => envelope({
              'name': 'WR-1',
              'status': 'Submitted',
              'review': {
                'route': 'managers_pool',
                'superior': null,
                'superior_name': null,
                'note': 'مافوق مستقیمی تعریف نشده؛ گزارش را مدیر کل سیستم یا مدیر منابع انسانی بررسی می‌کند.',
              },
            }));
    await tester.pumpWidget(_app(client, _Hr()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send_report_WR-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('مافوق مستقیمی تعریف نشده'), findsOneWidget);
  });

  testWidgets('the administrator composes today\'s report and sends it directly',
      (tester) async {
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => envelope({
              'name': 'WR-9',
              'status': 'Submitted',
              'review': {'route': 'managers_pool', 'note': 'یادداشت'},
            }));
    await tester.pumpWidget(_app(client, _Hr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('گزارش امروز'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'جلسه هماهنگی');
    await tester.tap(find.byKey(const Key('send_report_now')));
    await tester.pumpAndSettle();
    final captured = verify(() => client.callMethod(
        'asoud_erp.api.v1.hr.save_report',
        data: captureAny(named: 'data'))).captured.single as Map;
    expect((captured['payload'] as Map)['status'], 'Submitted');
    expect(((captured['payload'] as Map)['name']), isNull);
  });

  testWidgets('the server refusal is shown, not swallowed', (tester) async {
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenThrow(
        const ApiException(
            kind: ApiFailureKind.validation,
            message: 'گزارش بررسی‌شده قابل ویرایش نیست.'));
    await tester.pumpWidget(_app(client, _Hr()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send_report_WR-1')));
    await tester.pumpAndSettle();
    expect(find.text('گزارش بررسی‌شده قابل ویرایش نیست.'), findsOneWidget);
  });

  testWidgets('a failed report list shows its reason, not an empty page',
      (tester) async {
    await tester.pumpWidget(_app(client, _Hr(fail: true)));
    await tester.pumpAndSettle();
    expect(find.text('هنوز گزارش کاری ثبت نشده است'), findsNothing);
    expect(find.text('دریافت گزارش‌های کار ممکن نشد.'), findsOneWidget);
  });
}
