import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

class _Parties extends Fake implements PartyRepository {
  @override
  Future<List<PartyProfile>> list(
          {String? company, PartyRole? role, String? search}) async =>
      const [];
}

Widget _app(_Client client) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<PartyRepository>.value(value: _Parties()),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const DashboardPage(officeName: 'شرکت نمونه آسود'),
        ),
      ),
    );

void main() {
  late _Client client;

  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.callMethod(
          'asoud_erp.api.v1.dashboard.get_home_summary',
          data: any(named: 'data'),
        )).thenAnswer((_) async => {
          'message': {
            'meta': {'api_version': 'v1'},
            'data': {'company': 'شرکت نمونه آسود'},
          },
        });
  });

  _Client withRoles(List<String> roles) {
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        FrappeUserContext(userId: 'u', fullName: 'کاربر', roles: roles));
    return client;
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'signed-in Administrator opens parties from home quick action at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(withRoles(const ['Administrator'])));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('طرف حساب‌ها'));
      await tester.pumpAndSettle();
      expect(find.text('به‌زودی'), findsNothing);
      await tester.tap(find.text('طرف حساب‌ها'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyManagementPage), findsOneWidget);
      expect(find.text('اشخاص و شرکت‌ها'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a role without accounting sees the parties card disabled at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(_app(withRoles(const ['Purchase Manager'])));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('طرف حساب‌ها'));
      await tester.pumpAndSettle();
      expect(find.text('به‌زودی'), findsOneWidget);
      await tester.tap(find.text('طرف حساب‌ها'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyManagementPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}