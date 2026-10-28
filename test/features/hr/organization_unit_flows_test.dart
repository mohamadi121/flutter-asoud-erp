import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/domain/organization_templates.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

class _Client extends Fake implements FrappeApiClient {
  ApiException? unitsFailure;
  ApiException? saveUnitThrows;
  bool emptyChart = false;
  bool previewBreaks = false;
  final calls = <String>[];
  Object? failChartAfterDelete;

  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'Administrator',
      fullName: 'Administrator',
      roles: ['Administrator']);

  Map<String, dynamic> _ok(Map<String, dynamic> d) => {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': d
        }
      };

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    final name = method.split('.').last;
    calls.add(name);
    switch (name) {
      case 'preview_import':
        if (previewBreaks) throw StateError('boom');
        return _ok({'units': <dynamic>[], 'additions': <dynamic>[]});
      case 'get_chart':
        if (emptyChart) {
          return _ok({'rows': <dynamic>[], 'revision': 1, 'warnings': <dynamic>[]});
        }
        return _ok({
          'rows': [
            {
              'code': 'CEO',
              'title': 'مدیرعامل',
              'parent': '',
              'department': 'مدیریت',
              'occupants': ['HR-EMP-0001'],
              'capacity': 1,
              'duties': '',
              'assignment_history': [
                {
                  'employee': 'HR-EMP-0007',
                  'started_at': '2026-01-01 00:00:00',
                  'ended_at': null
                }
              ],
            }
          ],
          'revision': 1,
          'warnings': <dynamic>[],
        });
      case 'list_employees':
        return _ok({
          'employees': [
            {
              'id': 'HR-EMP-0007',
              'display_name': 'علی رضایی',
              'personnel_code': '۷'
            }
          ]
        });
      case 'list_units':
        if (unitsFailure != null) throw unitsFailure!;
        return _ok({
          'units': emptyChart ? <dynamic>[] : [
            {
              'name': 'HR-CO',
              'department_name': 'منابع انسانی',
              'parent_department': 'All Departments',
              'is_group': 0,
              'disabled': 0,
              'modified': '2026-10-22 10:00:00'
            }
          ],
          'can_manage': true
        });
      case 'preview_delete_unit':
        return _ok({'can_delete': true, 'blockers': <dynamic>[]});
      case 'delete_unit':
        return _ok({'deleted': true});
      case 'save_unit':
        if (saveUnitThrows != null) throw saveUnitThrows!;
        return _ok({'name': 'DEP-001', 'modified': '2026-10-22 10:00:00'});
    }
    throw StateError('Unexpected: $method');
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) async =>
      throw StateError('Unexpected write: $method');
}

Future<void> _open(WidgetTester tester, _Client client) async {
  tester.view.physicalSize = const Size(390, 900);
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
        child: OrganizationPage(company: 'شرکت', repository: repository),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}


Future<void> _openStructureTool(WidgetTester tester, String label) async {
  final scroll = find.byKey(const PageStorageKey('organization-focused-scroll'));
  if (scroll.evaluate().isNotEmpty) {
    final state = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first);
    state.position.jumpTo(state.position.minScrollExtent);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('ابزارهای ساختار'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('units tab tells a network failure from a forbidden one',
      (tester) async {
    final client = _Client()
      ..unitsFailure = const ApiException(
          kind: ApiFailureKind.forbidden, message: 'forbidden');
    await _open(tester, client);
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('organization-units-error')))
        .data;
    expect(shown, forbiddenFailureMessage);
    expect(find.text('دریافت واحدها ناموفق بود؛ تلاش دوباره'), findsOneWidget);
  });

  testWidgets('position history shows the employee name, not the id',
      (tester) async {
    await _open(tester, _Client());
    await _openStructureTool(tester, 'جایگاه‌ها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدیرعامل').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('سوابق انتساب'));
    await tester.pumpAndSettle();
    expect(find.text('علی رضایی'), findsOneWidget);
    expect(find.textContaining('HR-EMP-0007'), findsNothing);
  });

  testWidgets('deleting a unit previews blockers first and sends one delete',
      (tester) async {
    final client = _Client();
    await _open(tester, client);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final deleteAction = find.text('حذف واحد').last;
    await tester.ensureVisible(deleteAction);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    final check = find.text('حذف با تأیید نهایی');
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأیید حذف').last);
    await tester.pumpAndSettle();
    final preview = client.calls.indexOf('preview_delete_unit');
    final delete = client.calls.indexOf('delete_unit');
    expect(preview, greaterThanOrEqualTo(0));
    expect(delete, greaterThan(preview));
    expect(client.calls.where((c) => c == 'delete_unit'), hasLength(1));
  });

  testWidgets('an unexpected import preview failure is shown in Persian',
      (tester) async {
    final client = _Client()
      ..emptyChart = true
      ..previewBreaks = true;
    await _open(tester, client);
    await tester.tap(find.text('استفاده از قالب آماده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(organizationTemplates.first.title));
    await tester.pumpAndSettle();
    expect(find.text('پیش‌نمایش ورود آماده نشد؛ دوباره تلاش کنید.'),
        findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
  });

  test('a template unit whose title exists is matched by its real id', () {
    final template = organizationTemplates.first;
    final title = template.positions
        .firstWhere((p) => p.department.isNotEmpty)
        .department;
    final payload = templateOrganizationPayload(template, existingUnits: [
      {'name': 'REAL-1', 'department_name': title, 'disabled': 0}
    ]);
    final units = (payload['units'] as List).cast<Map<String, dynamic>>();
    expect(units.firstWhere((u) => u['title'] == title)['name'], 'REAL-1');
    expect(units.where((u) => u.containsKey('name')), hasLength(1));
    final fresh = templateOrganizationPayload(template);
    expect((fresh['units'] as List).any((u) => (u as Map).containsKey('name')),
        isFalse);
  });

  testWidgets('creating unit with ApiException boom displays Persian error, not raw server message',
      (tester) async {
    final client = _Client()
      ..saveUnitThrows = const ApiException(
          kind: ApiFailureKind.server, message: 'boom');
    await _open(tester, client);
    await _openStructureTool(tester, 'واحدها');
    await tester.pumpAndSettle();
    await tester.tap(find.text('واحد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'واحد فناوری');
    await tester.tap(find.byKey(const ValueKey('organization-compact-create-submit')));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsNothing);
    expect(find.text('خطایی در سرور رخ داد. کمی بعد دوباره تلاش کنید.'), findsOneWidget);
  });
}
