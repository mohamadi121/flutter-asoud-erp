import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository(this.office);

  final Office? office;

  @override
  Future<Office?> getDefaultOffice() async => office;

  @override
  Future<Office> createOffice(Office office) => throw UnimplementedError();

  @override
  Future<List<Office>> listOffices() async => office == null ? [] : [office!];

  @override
  Future<Office> setDefaultOffice(Office office) => throw UnimplementedError();

  @override
  Future<Office> updateOffice(String id, Office office) =>
      throw UnimplementedError();
}

class _RoleClient extends Fake implements FrappeApiClient {
  _RoleClient(this.roles);

  final List<String> roles;

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'user@asoud-demo.local',
        fullName: 'کاربر',
        roles: roles,
      );
}

Office _officeWithFlags({
  bool office = false,
  bool accounting = false,
  bool roles = false,
}) =>
    Office(
      name: 'شرکت نمونه آسود',
      type: OfficeType.legal,
      fiscalYearStart: DateTime(2026),
      setupComplete: office && accounting && roles,
      officeSaved: office,
      accountingSaved: accounting,
      rolesSaved: roles,
    );

Widget _page(
  Office? office, {
  List<String>? roles,
  double navBarBottom = 0,
}) {
  final app = MaterialApp(
    locale: const Locale('fa'),
    theme: AsoudTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: navBarBottom)),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: BaseAccountingSetupPage(officeName: 'شرکت نمونه آسود'),
      ),
    ),
  );
  return RepositoryProvider<OfficeRepository>.value(
    value: _OfficeRepository(office),
    child: roles == null
        ? app
        : RepositoryProvider<FrappeApiClient>.value(
            value: _RoleClient(roles), child: app),
  );
}

void main() {
  group('setup progress percentage', () {
    final cases = <int, String>{
      0: '۰٪ تکمیل شده',
      1: '۳۳٪ تکمیل شده',
      2: '۶۶٪ تکمیل شده',
      3: '۱۰۰٪ تکمیل شده',
    };
    for (final entry in cases.entries) {
      testWidgets('shows ${entry.value} for ${entry.key} saved flags',
          (tester) async {
        final flags = entry.key;
        await tester.pumpWidget(_page(_officeWithFlags(
          office: flags >= 1,
          accounting: flags >= 2,
          roles: flags >= 3,
        )));
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('33,'), findsNothing);
        final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progress.value, closeTo(flags / 3, 0.0001));
      });
    }
  });

  group('layout never overflows', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('renders locked tile reasons at $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_page(_officeWithFlags()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('به‌زودی'), findsNWidgets(2));
        expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      });

      testWidgets('does not overflow a short $width viewport', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_page(_officeWithFlags()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('role-locked modules explain why they are locked',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_page(
        _officeWithFlags(),
        roles: const ['Employee'],
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('برای شما فعال نیست؛ مدیر دسترسی بدهد'), findsWidgets);
    });

    testWidgets('bottom content clears the system navigation bar',
        (tester) async {
      await tester.pumpWidget(_page(_officeWithFlags(), navBarBottom: 48));
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView).first);
      final padding = listView.padding!.resolve(TextDirection.rtl);
      expect(padding.bottom, 64);
    });
  });
}
