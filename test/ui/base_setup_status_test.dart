import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('وضعیت راه‌اندازی پس از خطا با تلاش دوباره تکمیل می‌شود',
      (tester) async {
    final repository = _RetryOfficeRepository();
    await tester.pumpWidget(
      RepositoryProvider<OfficeRepository>.value(
        value: repository,
        child: MaterialApp(
          locale: const Locale('fa'),
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: BaseAccountingSetupPage(officeName: 'شرکت نمونه آسود'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دریافت وضعیت راه‌اندازی ناموفق بود.'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 2);
    expect(find.text('راه‌اندازی دفتر کامل شده است.'), findsOneWidget);
    expect(find.textContaining('وضعیت تکمیل از'), findsNothing);
    expect(find.text('33,'), findsNothing);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 1);
  });
}

class _RetryOfficeRepository implements OfficeRepository {
  int statusCalls = 0;

  @override
  Future<Office?> getDefaultOffice() async {
    statusCalls++;
    if (statusCalls == 1) throw Exception('network');
    return Office(
      name: 'شرکت نمونه آسود',
      type: OfficeType.legal,
      fiscalYearStart: DateTime(2026),
      setupComplete: true,
    );
  }

  @override
  Future<Office> createOffice(Office office) => throw UnimplementedError();

  @override
  Future<List<Office>> listOffices() => throw UnimplementedError();

  @override
  Future<Office> setDefaultOffice(Office office) => throw UnimplementedError();

  @override
  Future<Office> updateOffice(String id, Office office) =>
      throw UnimplementedError();
}
