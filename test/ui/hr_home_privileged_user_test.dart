import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/frappe_hr_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

class _FailedHrRepository extends Fake implements HrRepository {
  @override
  Future<HrDashboard> dashboard(String company) => throw const ApiException(
        kind: ApiFailureKind.validation,
        message: 'No active Employee is linked to this user',
      );
}

Widget _app(FrappeApiClient client, HrRepository repository) =>
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<HrRepository>.value(value: repository),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: HrHomePage(company: 'شرکت نمونه آسود'),
        ),
      ),
    );

void main() {
  testWidgets('مدیر سیستم بدون پرونده کارمند همه خدمات منابع انسانی را می‌بیند',
      (tester) async {
    final client = _Client();
    final currentUserResponse = {
      'message': {
        'ok': true,
        'data': {
          'user_id': 'Administrator',
          'full_name': 'Administrator',
          'roles': ['System Manager'],
          'employee': null,
        },
        'meta': {'api_version': 'v1'},
      },
    };
    when(client.getCurrentUser).thenAnswer(
      (_) async => FrappeUserContext.fromJson(
        Map<String, dynamic>.from(
          currentUserResponse['message']!['data']! as Map,
        ),
      ),
    );

    await tester.pumpWidget(_app(client, FrappeHrRepository(client)));
    await tester.pumpAndSettle();

    for (final label in [
      'لیست پرسنل',
      'درخواست‌های مرخصی',
      'حضور و غیاب',
      'گزارش کار روزانه',
      'اعلان‌های منابع انسانی',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    verifyNever(() => client.callAsoudMethod(
          'asoud_erp.api.v1.hr.get_dashboard',
          data: any(named: 'data'),
        ));
  });

  testWidgets('خطای واقعی داشبورد دلیل فارسی و تلاش دوباره را نشان می‌دهد',
      (tester) async {
    final client = _Client();
    await tester.pumpWidget(_app(client, _FailedHrRepository()));
    await tester.pumpAndSettle();

    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(find.textContaining('حساب کاربری شما به پرسنل فعال متصل نیست'),
        findsOneWidget);
  });
}
