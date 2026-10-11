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

Future<void> _openCreateForm(WidgetTester tester, _OrgClient client) async {
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

  await tester.tap(find.text('ایجاد ساختار دستی'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the position form uses AppTextField and AppSelectField',
      (tester) async {
    await _openCreateForm(tester, _OrgClient());

    expect(find.text('عنوان جایگاه *'), findsOneWidget);
    expect(find.text('کد جایگاه *'), findsOneWidget);
    expect(find.text('واحد سازمانی'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.byType(AppSelectField), findsOneWidget);
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

    await tester.tap(find.byType(AppSelectField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جایگاه خالی').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ذخیره جایگاه'));
    await tester.pumpAndSettle();

    expect(client.writes, contains('asoud_erp.api.v1.organization.save_chart'));
    final rows = (client.lastSavePayload!['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    expect(rows.any((row) => row['code'] == 'FIN' && row['title'] == 'مدیر مالی'),
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
