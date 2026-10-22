import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Administrator client with the real backend envelope shapes; the write goes
/// through [callAsoudMethod], exactly as [OrganizationRepository.save] calls it.
class _OrgClient extends Fake implements FrappeApiClient {
  _OrgClient({this.units = const []});
  final List<Map<String, dynamic>> units;
  Map<String, dynamic>? lastUnitPayload;
  final writes = <String>[];
  Map<String, dynamic>? lastSavePayload;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: const ['Administrator'],
      );

  Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': data,
        },
      };

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.get_chart') {
      return _envelope({
        'rows': [
          {
            'code': 'CEO',
            'title': 'مدیرعامل',
            'parent': '',
            'department': 'مدیریت',
            'employee': 'EMP-001',
          }
        ],
        'revision': 1,
        'warnings': <dynamic>[],
      });
    }
    if (method == 'asoud_erp.api.v1.organization.list_employees') {
      return _envelope({'employees': <dynamic>[]});
    }
    if (method == 'asoud_erp.api.v1.organization.list_units') {
      return _envelope({'units': units, 'can_manage': true});
    }
    if (method == 'asoud_erp.api.v1.organization.save_unit') {
      lastUnitPayload = Map<String, dynamic>.from(data!['payload'] as Map);
      return _envelope({'name': lastUnitPayload!['name'] ?? 'NEW-UNIT'});
    }
    throw StateError('Unexpected organization read: $method');
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.save_chart') {
      writes.add(method);
      final payload = Map<String, dynamic>.from(data!['payload'] as Map);
      lastSavePayload = payload;
      return {
        'rows': payload['rows'],
        'revision': (payload['revision'] as int) + 1,
        'warnings': <dynamic>[],
      };
    }
    throw StateError('Unexpected organization write: $method');
  }
}

Future<void> _openCreateForm(WidgetTester tester, _OrgClient client,
    {bool openForm = true}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository =
      OrganizationRepository(client, local: FakeLocalRecordStore());
  addTearDown(repository.dispose);
  await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
    value: client,
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OrganizationPage(
          company: 'شرکت نمونه آسود',
          repository: repository,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  if (!openForm) return;
  await tester.tap(find.text('جایگاه‌ها'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('عملیات جایگاه'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('افزودن زیرمجموعه'));
  await tester.pumpAndSettle();
}

void main() {
  const unit = {
    'name': 'HR-CO',
    'department_name': 'منابع انسانی',
    'parent_department': 'All Departments',
    'is_group': 1,
    'disabled': 0,
    'modified': '2026-10-22 10:00:00'
  };

  testWidgets(
      'editing a unit preserves its native root outside the company list',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('واحدها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('organization-unit-edit'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('All Departments'), findsOneWidget);
    final save = find.byKey(const ValueKey('organization-unit-submit'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!['name'], 'HR-CO');
    expect(client.lastUnitPayload!['parent'], 'All Departments');
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a subunit starts blank and does not edit its parent',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('واحدها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('organization-subunit-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final title = find.widgetWithText(TextFormField, 'عنوان واحد *');
    expect(tester.widget<TextFormField>(title).controller!.text, isEmpty);
    await tester.enterText(title, 'آموزش');
    final submit = find.byKey(const ValueKey('organization-unit-submit'));
    expect(submit, findsOneWidget);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    expect(client.lastUnitPayload!['parent'], 'HR-CO');
    expect(client.lastUnitPayload!['title'], 'آموزش');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('organization management and visual report fit at $width',
        (tester) async {
      final client = _OrgClient();
      await _openCreateForm(tester, client);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      expect(find.text('واحدها'), findsOneWidget);
      expect(find.text('جایگاه‌ها'), findsOneWidget);
      await tester.tap(find.text('واحدها'));
      await tester.pumpAndSettle();
      expect(find.text('هنوز واحدی تعریف نشده است.'), findsOneWidget);
      await tester.tap(find.text('جایگاه‌ها'));
      await tester.pumpAndSettle();
      expect(find.text('جایگاه‌های سازمانی'), findsOneWidget);
      await tester.tap(find.text('چارت سازمانی'));
      await tester.pumpAndSettle();
      final report = find.text('گزارش تصویری چارت');
      // A cached child can exist below the viewport in NestedScrollView.
      // Real gestures scroll both coordinated viewports; wait for a hit target,
      // not merely for the lazy child to have been built.
      for (var attempt = 0;
          attempt < 20 && report.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byType(TabBarView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(report.hitTestable(), findsOneWidget);
      await tester.tap(report.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('نمای فهرستی'), findsOneWidget);
      expect(find.text('ورود از اکسل'), findsOneWidget);
      expect(find.text('ایجاد دستی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the position form uses AppTextField and AppSelectField',
      (tester) async {
    await _openCreateForm(tester, _OrgClient());

    expect(find.text('عنوان جایگاه *'), findsOneWidget);
    expect(find.text('کد جایگاه *'), findsOneWidget);
    expect(find.widgetWithText(AppSelectField, 'واحد سازمانی'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(4));
    expect(find.byType(AppSelectField), findsNWidgets(3));
    expect(find.text('ظرفیت *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the position form validates, fills and submits a position',
      (tester) async {
    final client = _OrgClient();
    await _openCreateForm(tester, client);

    await tester.tap(find.text('ذخیره جایگاه'));
    await tester.pumpAndSettle();
    expect(find.text('عنوان جایگاه را وارد کنید.'), findsOneWidget);
    expect(find.text('کد جایگاه را وارد کنید.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان جایگاه *'), 'مدیر مالی');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'کد جایگاه *'), 'FIN');

    await tester.tap(find.byKey(const ValueKey('org-employee-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جایگاه خالی').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ذخیره جایگاه'));
    await tester.pumpAndSettle();

    expect(client.writes, contains('asoud_erp.api.v1.organization.save_chart'));
    final rows = (client.lastSavePayload!['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    expect(
        rows.any((row) => row['code'] == 'FIN' && row['title'] == 'مدیر مالی'),
        isTrue);
    final created = rows.singleWhere((r) => r['code'] == 'FIN');
    expect(created['occupants'], isEmpty);
    expect(created['capacity'], 1);
    expect(tester.takeException(), isNull);
  });
}
