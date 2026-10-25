import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

Widget _app(_Client client, Office office) => RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: DashboardPage(office: office, officeName: office.name)),
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.getCurrentUser()).thenThrow(Exception('offline'));
  });

  testWidgets('incomplete setup shows the card with the real step count',
      (tester) async {
    final office = Office(
        name: 'دفتر آزمون',
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2026, 3, 21),
        officeSaved: true,
        accountingSaved: false,
        rolesSaved: false);
    await tester.pumpWidget(_app(client, office));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('راه‌اندازی دفتر کار'), findsOneWidget);
    expect(find.text('ادامه راه‌اندازی'), findsOneWidget);
    expect(find.text('راه‌اندازی دفتر هنوز کامل نیست'), findsOneWidget);
    expect(find.textContaining('۱ از ۳'), findsOneWidget);
  });

  testWidgets('complete setup hides the card', (tester) async {
    final office = Office(
        name: 'دفتر آزمون',
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2026, 3, 21),
        setupComplete: true);
    await tester.pumpWidget(_app(client, office));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ادامه راه‌اندازی'), findsNothing);
  });
}
