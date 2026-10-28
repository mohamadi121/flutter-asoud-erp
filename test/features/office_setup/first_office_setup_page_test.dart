import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/first_office_setup_page.dart';

class _FakeSetupClient extends Fake implements FrappeApiClient {
  final calls = <String>[];
  final Map<String, dynamic> methodData = {};

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges =>
      StreamController<bool>(onCancel: () async {}).stream;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@example.com',
        fullName: 'مدیر سیستم',
        roles: ['System Manager', 'Administrator'],
      );

  @override
  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    calls.add(method);
    if (data != null) {
      methodData[method] = data;
    }
    if (method == 'asoud_erp.api.v1.first_office_setup.status') {
      return {
        'message': {
          'ok': true,
          'data': {
            'company': 'شرکت آزمون',
            'hr_lead': null,
            'hr_ready': false,
            'completed': false,
          },
        },
      };
    }
    if (method == 'asoud_erp.api.v1.first_office_setup.complete') {
      return {
        'message': {
          'ok': true,
          'data': {
            'company': 'شرکت آزمون',
            'hr_lead': null,
            'hr_ready': false,
            'completed': true,
          },
        },
      };
    }
    if (method == 'asoud_erp.api.v1.calendar.get_calendar') {
      return {
        'message': {
          'ok': true,
          'data': {'items': [], 'can_manage': false},
        },
      };
    }
    return {'message': {'ok': true, 'data': {}}};
  }

  @override
  Future<dynamic> callAsoudMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    calls.add(method);
    if (data != null) {
      methodData[method] = data;
    }
    if (method == 'asoud_erp.api.v1.setup.list_fiscal_years') {
      return [
        {
          'name': '1405',
          'year': 1405,
          'year_start_date': '2026-03-21',
          'year_end_date': '2027-03-20',
          'disabled': 0,
        }
      ];
    }
    if (method == 'asoud_erp.api.v1.calendar.get_calendar') {
      return {'items': [], 'can_manage': false};
    }
    return {};
  }
}

class _FakeOfficeRepository extends Fake implements OfficeRepository {
  @override
  Future<List<Office>> listOffices() async => [
        Office(
          name: 'شرکت آزمون',
          type: OfficeType.legal,
          fiscalYearStart: DateTime(2026, 3, 21),
          setupComplete: true,
        ),
      ];

  @override
  Future<Office?> getDefaultOffice() async => Office(
        name: 'شرکت آزمون',
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2026, 3, 21),
        setupComplete: true,
      );
}

Widget _buildTestApp(FrappeApiClient client, double width) {
  return MaterialApp(
    locale: const Locale('fa'),
    theme: AsoudTheme.light,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox(),
    ),
    home: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<OfficeRepository>.value(
            value: _FakeOfficeRepository()),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 1000)),
        child: const FirstOfficeSetupPage(company: 'شرکت آزمون'),
      ),
    ),
  );
}

void main() {
  testWidgets('renders first office setup review at 320, 390, and 430 px',
      (tester) async {
    for (final width in [320.0, 390.0, 430.0]) {
      final client = _FakeSetupClient();
      await tester.binding.setSurfaceSize(Size(width, 1200));
      await tester.pumpWidget(_buildTestApp(client, width));
      await tester.pumpAndSettle();

      expect(find.text('راه‌اندازی دفتر کار'), findsOneWidget);
      expect(find.text('مراحل اولیه آمادهٔ تأیید هستند'), findsOneWidget);
      expect(find.text('سال مالی ثبت شده است. معرفی مسئول منابع انسانی در این مرحله الزامی نیست؛ کاربران، نقش‌ها، ساختار سازمانی و گردش کار بعد از ورود به خانهٔ آسود تنظیم می‌شوند.'), findsOneWidget);
    }
  });

  testWidgets(
      'entering home records completion on server via first_office_setup.complete',
      (tester) async {
    final client = _FakeSetupClient();
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    await tester.pumpWidget(_buildTestApp(client, 390));
    await tester.pumpAndSettle();

    expect(client.calls, contains('asoud_erp.api.v1.first_office_setup.status'));
    expect(client.calls, isNot(contains('asoud_erp.api.v1.first_office_setup.complete')));

    final enterButton = find.text('تأیید نهایی و ورود به خانه  ←');
    expect(enterButton, findsOneWidget);
    await tester.tap(enterButton);
    await tester.pumpAndSettle();

    expect(client.calls, contains('asoud_erp.api.v1.first_office_setup.complete'));
    expect(
      client.methodData['asoud_erp.api.v1.first_office_setup.complete'],
      equals({'company': 'شرکت آزمون'}),
    );
  });
}
