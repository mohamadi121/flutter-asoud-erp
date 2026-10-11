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

class _EmptyHr extends Fake implements HrRepository {
  @override
  Future<List<WorkReport>> reports() async => const [];
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) async =>
      const [];
}

Widget _app(_Client client) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<HrRepository>.value(value: _EmptyHr()),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const WorkReportsPage(company: 'شرکت نمونه آسود'),
        ),
      ),
    );

void main() {
  late _Client client;

  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        FrappeUserContext(
            userId: 'u', fullName: 'کاربر', roles: const ['Employee']));
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('an employee can write own daily report at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(client));
      await tester.pumpAndSettle();

      expect(find.text('گزارش امروز'), findsOneWidget);
      await tester.tap(find.text('گزارش امروز'));
      await tester.pumpAndSettle();
      expect(find.text('افزودن فعالیت'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an employee can write own correspondence at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FrappeApiClient>.value(value: client),
          RepositoryProvider<HrRepository>.value(value: _EmptyHr()),
        ],
        child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: const HrCommunicationsPage(company: 'شرکت نمونه آسود'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مکاتبه جدید'), findsOneWidget);
      await tester.tap(find.text('مکاتبه جدید'));
      await tester.pumpAndSettle();
      expect(find.text('ایجاد مکاتبه'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-employee manager sees no self-service write buttons '
        'at $width', (tester) async {
      when(() => client.getCurrentUser()).thenAnswer((_) async =>
          FrappeUserContext(
              userId: 'm',
              fullName: 'مدیر',
              roles: const ['Accounts Manager']));
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FrappeApiClient>.value(value: client),
          RepositoryProvider<HrRepository>.value(value: _EmptyHr()),
        ],
        child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: const WorkReportsPage(company: 'شرکت نمونه آسود'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('گزارش امروز'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FrappeApiClient>.value(value: client),
          RepositoryProvider<HrRepository>.value(value: _EmptyHr()),
        ],
        child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: const HrCommunicationsPage(company: 'شرکت نمونه آسود'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('مکاتبه جدید'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}