import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/data/workflow_card_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Map<String, dynamic> _row(String id, {bool system = false, bool locked = false}) => {
  'name': id, 'workflow_code': system ? 'SYS-LEAVE' : 'WF-1',
  'workflow_title': system ? 'گردش سیستمی' : 'گردش ساخته‌شده',
  'target_doctype': 'ASOUD Workflow Request', 'status': 'Inactive',
  'readiness_status': locked ? 'Pending' : 'Ready', 'is_locked': locked,
  'missing_requirements': <String>[], 'version_no': 1, 'steps_count': 3,
  'modified': null, 'is_system_template': system ? 1 : 0,
  'template_key': system ? 'leave' : null, 'can_delete': !system,
};

class _Server extends Mock implements FrappeApiClient {
  final rows = <Map<String, dynamic>>[_row('custom'), _row('system', system: true)];
  int writes = 0;
  bool reject = false;
  String rejection = 'این گردش‌کار دارای سابقهٔ اجرا است؛ تغییر مجاز نیست.';
  Completer<void>? gate;
  @override
  bool get isAuthenticated => true;
  @override
  Future<dynamic> callAsoudMethod(String method, {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.workflow.get_workflow_design') {
      return {'workflow': rows.singleWhere((row) => row['name'] == data!['definition']),
        'stages': <Map<String, dynamic>>[], 'transitions': <Map<String, dynamic>>[],
        'details_summary': {'steps_count': 0, 'stages_complete': false, 'routes_complete': false,
          'requirements': ['گردش‌کار باید یک شروع و دست‌کم یک پایان داشته باشد.']}};
    }
    expect(method, 'asoud_erp.api.v1.workflow.list_workflows');
    return rows.where((row) => data?['status'] == null || row['status'] == data!['status'])
        .map((row) => Map<String, dynamic>.from(row)).toList();
  }
  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    writes++;
    await gate?.future;
    if (reject) {
      throw ApiException(kind: ApiFailureKind.validation, message: rejection);
    }
    final row = rows.singleWhere((row) => row['name'] == data!['name']);
    if (method == 'asoud_erp.api.v1.workflow.delete_workflow') {
      final row = rows.singleWhere((row) => row['name'] == data!['name']);
      rows.remove(row);
      return {'message': {'ok': true, 'data': {'name': data!['name'], 'deleted': true}}};
    }
    expect(method, 'asoud_erp.api.v1.workflow.set_workflow_status');
    row['status'] = data!['status'];
    return {'message': {'ok': true, 'data': Map<String, dynamic>.from(row)}};
  }
}

Future<void> _open(WidgetTester tester, _Server server, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MultiRepositoryProvider(providers: [
    RepositoryProvider<WorkflowRepository>.value(value: FrappeWorkflowRepository(server)),
    RepositoryProvider<WorkflowCardRepository>.value(value: WorkflowCardRepository(server)),
  ], child: MaterialApp(builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: WorkflowListPage(key: UniqueKey()))));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String title) async {
  final card = find.ancestor(of: find.text(title), matching: find.byType(Card));
  await tester.tap(find.descendant(of: card, matching: find.byType(PopupMenuButton<String>)));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('switching filter while status write is pending still refreshes at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server()..gate = Completer<void>();
      await _open(tester, server, width);
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('فعال‌سازی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فعال').first);
      await tester.pumpAndSettle();
      expect(find.text('گردش ساخته‌شده'), findsNothing);
      server.gate!.complete();
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(find.text('گردش ساخته‌شده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('incomplete workflow remains inactive after server validation at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server()..reject = true
        ..rejection = 'فعال‌سازی ممکن نیست: مسیر خروج مرحله کامل نیست.';
      server.rows.first['is_locked'] = true;
      await _open(tester, server, width);
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('فعال‌سازی'));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.rows.first['status'], 'Inactive');
      expect(find.text(server.rejection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('status toggles persist, reload, and honor active filter at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server();
      await _open(tester, server, width);
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('فعال‌سازی'));
      await tester.pumpAndSettle();
      expect(server.rows.first['status'], 'Active');
      expect(server.writes, 1);
      await _open(tester, server, width);
      await _menu(tester, 'گردش ساخته‌شده');
      expect(find.text('غیرفعال‌سازی'), findsOneWidget);
      await tester.tap(find.text('غیرفعال‌سازی'));
      await tester.pumpAndSettle();
      expect(server.rows.first['status'], 'Inactive');
      await _open(tester, server, width);
      await tester.tap(find.text('فعال').first);
      await tester.pumpAndSettle();
      expect(find.text('گردش ساخته‌شده'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete confirms, cancel is read-only, system has no delete at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server();
      await _open(tester, server, width);
      await _menu(tester, 'گردش سیستمی');
      expect(find.text('حذف'), findsNothing);
      await tester.tap(find.text('مشاهده جزئیات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بستن'));
      await tester.pumpAndSettle();
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف'));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(find.text('گردش ساخته‌شده'), findsNothing);
      await _open(tester, server, width);
      expect(find.text('گردش ساخته‌شده'), findsNothing);
      expect(find.text('گردش سیستمی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('server refusal retains previous status and explains reason at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server()..reject = true;
      await _open(tester, server, width);
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('فعال‌سازی'));
      await tester.pumpAndSettle();
      expect(server.rows.first['status'], 'Inactive');
      expect(find.text('این گردش‌کار دارای سابقهٔ اجرا است؛ تغییر مجاز نیست.'), findsOneWidget);
      await _menu(tester, 'گردش ساخته‌شده');
      expect(find.text('فعال‌سازی'), findsOneWidget);
      expect(find.text('غیرفعال‌سازی'), findsNothing);
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف'));
      await tester.pumpAndSettle();
      expect(find.text('گردش ساخته‌شده'), findsOneWidget);
      expect(server.rows.length, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deactivation removes card from active filter without resetting it at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server();
      server.rows.first['status'] = 'Active';
      await _open(tester, server, width);
      await tester.tap(find.text('فعال').first);
      await tester.pumpAndSettle();
      await _menu(tester, 'گردش ساخته‌شده');
      await tester.tap(find.text('غیرفعال‌سازی'));
      await tester.pumpAndSettle();
      expect(server.rows.first['status'], 'Inactive');
      expect(find.text('گردش ساخته‌شده'), findsNothing);
      await tester.tap(find.text('غیرفعال').first);
      await tester.pumpAndSettle();
      expect(find.text('گردش ساخته‌شده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
