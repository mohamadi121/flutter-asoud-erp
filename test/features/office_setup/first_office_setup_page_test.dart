import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/first_office_setup_page.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/first_hr_lead_form.dart';

class _FakeSetupClient extends Fake implements FrappeApiClient {
  final calls = <String>[];
  final Map<String, dynamic> methodData = {};
  Completer<Map<String, dynamic>>? createGate;
  Map<String, dynamic>? statusLead;
  Object? statusError;
  Object? fiscalLoadError, fiscalSaveError;
  bool emptyFiscalYears = false;

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
    if (method == 'asoud_erp.api.v1.first_office_setup.create_hr_lead') {
      return createGate!.future;
    }
    if (method == 'asoud_erp.api.v1.first_office_setup.status') {
      if (statusError != null) throw statusError!;
      return {
        'message': {
          'ok': true,
          'data': {
            'company': 'شرکت آزمون',
            'hr_lead': statusLead,
            'hr_ready': statusLead != null,
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
      if (fiscalLoadError != null) throw fiscalLoadError!;
      if (emptyFiscalYears) return [];
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
    if (method == 'asoud_erp.api.v1.setup.create_fiscal_year' &&
        fiscalSaveError != null) throw fiscalSaveError!;
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
  for (final saveFailure in [true, false]) {
    testWidgets('fiscal validation preserves server reason; save=$saveFailure',
        (tester) async {
      const reason = 'سال مالی با دوره ثبت‌شده هم‌پوشانی دارد.';
      const failure = ApiException(kind: ApiFailureKind.validation,
          statusCode: 417, message: reason);
      final client = _FakeSetupClient()
        ..emptyFiscalYears = true
        ..fiscalSaveError = saveFailure ? failure : null
        ..fiscalLoadError = saveFailure ? null : failure;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      await tester.pumpWidget(_buildTestApp(client, 390));
      await tester.pumpAndSettle();
      if (saveFailure) {
        final save = find.text('ذخیره و ادامه  ←');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
      }
      expect(find.text(reason), findsOneWidget);
      expect(find.text('اطلاعات واردشده را بررسی کنید.'), findsNothing);
    });
  }
  for (final kind in [ApiFailureKind.timeout, ApiFailureKind.network,
    ApiFailureKind.protocol]) {
    for (final exists in [true, false]) {
      testWidgets('$kind requires reconciliation before retry; lead=$exists',
          (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 1200));
        final client = _FakeSetupClient()
          ..createGate = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(_buildTestApp(client, 390));
        await tester.pumpAndSettle();
        final fields = find.descendant(of: find.byType(FirstHrLeadForm),
            matching: find.byType(TextFormField));
        for (final entry in ['علی رضایی', 'hr_lead', '09123456789',
          'Temporary123!'].asMap().entries) {
          await tester.ensureVisible(fields.at(entry.key));
          await tester.enterText(fields.at(entry.key), entry.value);
        }
        final submit = find.text('ثبت مسئول منابع انسانی و ادامه  ←');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        client.createGate!.completeError(ApiException(kind: kind));
        await tester.pumpAndSettle();
        expect(tester.widget<FirstHrLeadForm>(find.byType(FirstHrLeadForm))
            .enabled, isFalse);
        expect(client.calls.where((m) => m.endsWith('.create_hr_lead')).length, 1);
        client.statusError = const ApiException(kind: ApiFailureKind.network);
        final reload = find.text('دریافت دوباره وضعیت راه‌اندازی');
        await tester.ensureVisible(reload);
        await tester.tap(reload);
        await tester.pumpAndSettle();
        expect(tester.widget<FirstHrLeadForm>(find.byType(FirstHrLeadForm))
            .enabled, isFalse);
        client.statusError = null;
        if (exists) client.statusLead = {'full_name': 'علی رضایی',
          'username': 'hr_lead', 'role_title': 'مسئول منابع انسانی'};
        await tester.ensureVisible(reload);
        await tester.tap(reload);
        await tester.pumpAndSettle();
        if (exists) {
          expect(find.byType(FirstHrLeadForm), findsNothing);
          expect(find.text('علی رضایی'), findsOneWidget);
        } else {
          expect(tester.widget<FirstHrLeadForm>(find.byType(FirstHrLeadForm))
              .enabled, isTrue);
        }
        expect(client.calls.where((m) => m.endsWith('.create_hr_lead')).length, 1);
      });
    }
  }
  testWidgets('renders first office setup review at 320, 390, and 430 px',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 430.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final client = _FakeSetupClient();
      await tester.binding.setSurfaceSize(Size(width, 1200));
      await tester.pumpWidget(_buildTestApp(client, width));
      await tester.pumpAndSettle();

      expect(find.text('راه‌اندازی دفتر کار'), findsOneWidget);
      expect(find.text('۲. معرفی اولین مسئول منابع انسانی'), findsOneWidget);
      expect(find.byType(FirstHrLeadForm), findsOneWidget);
      final later = find.text('بعداً؛ ادامه به بررسی نهایی');
      await tester.ensureVisible(later);
      await tester.pumpAndSettle();
      await tester.tap(later);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('مراحل اولیه آمادهٔ تأیید هستند'));
      expect(find.text('مراحل اولیه آمادهٔ تأیید هستند'), findsOneWidget);
      expect(find.text('سال مالی ثبت شده است. معرفی مسئول منابع انسانی در این مرحله الزامی نیست؛ کاربران، نقش‌ها، ساختار سازمانی و گردش کار بعد از ورود به خانهٔ آسود تنظیم می‌شوند.'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    final later = find.text('بعداً؛ ادامه به بررسی نهایی');
    await tester.ensureVisible(later);
    await tester.pumpAndSettle();
    await tester.tap(later);
    await tester.pumpAndSettle();

    final enterButton = find.text('تأیید نهایی و ورود به خانه  ←');
    expect(enterButton, findsOneWidget);
    await tester.ensureVisible(enterButton);
    await tester.pumpAndSettle();
    await tester.tap(enterButton);
    await tester.pumpAndSettle();

    expect(client.calls, contains('asoud_erp.api.v1.first_office_setup.complete'));
    expect(
      client.methodData['asoud_erp.api.v1.first_office_setup.complete'],
      equals({'company': 'شرکت آزمون'}),
    );
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('HR validation ends busy state and permits retry at $width',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _FakeSetupClient()
        ..createGate = Completer<Map<String, dynamic>>();
      await tester.binding.setSurfaceSize(Size(width, 1200));
      await tester.pumpWidget(_buildTestApp(client, width));
      await tester.pumpAndSettle();
      final fields = find.descendant(
          of: find.byType(FirstHrLeadForm), matching: find.byType(TextFormField));
      for (final entry in ['علی رضایی', 'hr_lead', '09123456789', 'Temporary123!'].asMap().entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.pumpAndSettle();
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      final submit = find.text('ثبت مسئول منابع انسانی و ادامه  ←');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('در حال ثبت…'), findsOneWidget);
      expect(client.methodData['asoud_erp.api.v1.first_office_setup.create_hr_lead'], equals({
        'company': 'شرکت آزمون', 'full_name': 'علی رضایی',
        'username': 'hr_lead', 'contact': '09123456789',
        'temporary_password': 'Temporary123!',
      }));
      const reason = 'نام کاربری یا اطلاعات تماس قبلاً برای حساب دیگری ثبت شده است.';
      client.createGate!.completeError(const ApiException(
          kind: ApiFailureKind.validation, statusCode: 417, message: reason));
      await tester.pumpAndSettle();
      expect(find.text('در حال ثبت…'), findsNothing);
      await tester.ensureVisible(find.text(reason));
      expect(find.text(reason), findsOneWidget);
      expect(find.text('اطلاعات واردشده را بررسی کنید.'), findsNothing);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.ancestor(
          of: submit, matching: find.byType(FilledButton))).onPressed, isNotNull);

      client.createGate = Completer<Map<String, dynamic>>();
      await tester.tap(submit);
      await tester.pump();
      expect(client.calls.where((m) => m.endsWith('.create_hr_lead')).length, 2);
      client.createGate!.complete({'message': {'ok': true, 'data': {
        'company': 'شرکت آزمون', 'hr_lead': {
          'full_name': 'علی رضایی', 'username': 'hr_lead',
          'role_title': 'مسئول منابع انسانی'},
        'hr_ready': true, 'completed': false,
      }}});
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('مراحل اولیه آمادهٔ تأیید هستند'));
      expect(find.text('مراحل اولیه آمادهٔ تأیید هستند'), findsOneWidget);
      expect(find.text('در حال ثبت…'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
