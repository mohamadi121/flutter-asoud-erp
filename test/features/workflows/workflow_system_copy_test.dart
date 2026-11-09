import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _systemModified = '2026-01-01 10:20:30.123456';
const _refusal = 'ابتدا یک کپی مستقل از الگوی سیستمی بسازید.';

Map<String, dynamic> _row(String id, {bool system = false}) => {
  'name': id,
  'workflow_code': system ? 'SYS-LEAVE' : 'WF-1',
  'workflow_title': system ? 'گردش سیستمی' : 'گردش ساخته‌شده',
  'target_doctype': 'ASOUD Workflow Request',
  'status': 'Inactive',
  'readiness_status': 'Ready',
  'is_locked': false,
  'missing_requirements': <String>[],
  'version_no': 1,
  'steps_count': 3,
  'modified': system ? _systemModified : null,
  'company': 'دفتر نمونه',
  'is_system_template': system ? 1 : 0,
  'template_key': system ? 'leave' : null,
  'can_delete': !system,
};

/// The definition the server returns for a freshly created independent copy.
Map<String, dynamic> _copyRow() => {
  'name': 'WF-1405-001',
  'workflow_code': 'WF-1405-001',
  'workflow_title': 'گردش سیستمی - کپی',
  'target_doctype': 'ASOUD Workflow Request',
  'status': 'Inactive',
  'readiness_status': 'Pending',
  'is_locked': true,
  'missing_requirements': <String>['بررسی مراحل', 'اتصال گردش کار'],
  'version_no': 1,
  'steps_count': 3,
  'modified': '2026-02-01 09:00:00.000000',
  'company': 'دفتر نمونه',
  'is_system_template': 0,
  'template_key': null,
  'can_delete': true,
};

class _Server extends Mock implements FrappeApiClient {
  final rows = <Map<String, dynamic>>[
    _row('custom'),
    _row('system', system: true),
  ];
  Map<String, dynamic>? copyArgs;
  int saves = 0;
  bool rejectCopy = false;
  String copyRejection = 'الگو تغییر کرده است؛ آن را دوباره انتخاب کنید.';
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'admin', fullName: 'مدیر', roles: ['System Manager']);
  @override
  Future<dynamic> callAsoudMethod(String method, {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.workflow_templates.create_from_template') {
      copyArgs = Map<String, dynamic>.from(data!);
      if (rejectCopy) {
        throw ApiException(kind: ApiFailureKind.validation, message: copyRejection);
      }
      rows.add(_copyRow());
      return _copyRow();
    }
    if (method == 'asoud_erp.api.v1.workflow.get_workflow_design') {
      final row = rows.singleWhere((row) => row['name'] == data!['definition']);
      return {
        'workflow': Map<String, dynamic>.from(row),
        'stages': <Map<String, dynamic>>[],
        'transitions': <Map<String, dynamic>>[],
        'details_summary': {
          'steps_count': 0,
          'stages_complete': false,
          'routes_complete': false,
          'requirements': <String>['گردش‌کار باید یک شروع و دست‌کم یک پایان داشته باشد.']
        },
      };
    }
    if (method == 'asoud_erp.api.v1.workflow.workflow_form_options') {
      return {'companies': <String>['دفتر نمونه'], 'modules': <Map<String, dynamic>>[],
        'roles': <String>[], 'departments': <Map<String, dynamic>>[],
        'employees': <Map<String, dynamic>>[]};
    }
    expect(method, 'asoud_erp.api.v1.workflow.list_workflows');
    return rows
        .where((row) => data?['status'] == null || row['status'] == data!['status'])
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.workflow.save_stage_settings' ||
        method == 'asoud_erp.api.v1.workflow.save_start_settings') {
      saves++;
    }
    throw StateError('unexpected write: $method');
  }
}

WorkflowDesign _systemDesign() => WorkflowDesign(
    workflow: WorkflowDefinition(
        id: 'system',
        code: 'SYS-LEAVE',
        title: 'گردش سیستمی',
        targetDoctype: 'ASOUD Workflow Request',
        status: WorkflowDefinitionStatus.inactive,
        isLocked: false,
        version: 1,
        stepsCount: 3,
        modified: DateTime.tryParse(_systemModified),
        modifiedRaw: _systemModified,
        company: 'دفتر نمونه',
        isSystemTemplate: true,
        templateKey: 'leave'),
    stages: const [
      WorkflowStage(id: 'start', key: 'start', type: WorkflowStageType.start,
          title: 'شروع', sequence: 0, configurationComplete: true)
    ],
    transitions: const []);

class _DesignRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<WorkflowDesign> getDesign(String definition) async => _systemDesign();
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: ['دفتر نمونه'], modules: []);
}

/// A repository whose stage save is refused by the server with the copy message.
class _RefusingRepository extends _DesignRepository {
  @override
  Future<WorkflowDesign> saveStageSettings({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
  }) async =>
      throw ApiException(kind: ApiFailureKind.validation, message: _refusal);
}

Future<void> _openList(WidgetTester tester, _Server server, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MultiRepositoryProvider(providers: [
    RepositoryProvider<WorkflowRepository>.value(value: FrappeWorkflowRepository(server)),
    RepositoryProvider<FrappeApiClient>.value(value: server),
  ], child: MaterialApp(
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
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
    testWidgets('copy menu only for system workflow, opens copy designer at $width',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server();
      await _openList(tester, server, width);
      // Non-system card has no copy entry.
      await _menu(tester, 'گردش ساخته‌شده');
      expect(find.text('ایجاد کپی مستقل'), findsNothing);
      await tester.tap(find.text('مشاهده جزئیات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بستن'));
      await tester.pumpAndSettle();
      // System card offers the copy entry.
      await _menu(tester, 'گردش سیستمی');
      expect(find.text('ایجاد کپی مستقل'), findsOneWidget);
      await tester.tap(find.text('ایجاد کپی مستقل'));
      await tester.pumpAndSettle();
      // Dialog defaults the title to «<title> - کپی».
      expect(find.text('گردش سیستمی - کپی'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'ایجاد کپی'));
      await tester.pumpAndSettle();
      // The copy call used the system workflow as source with its raw modified.
      expect(server.copyArgs, isNotNull);
      expect(server.copyArgs!['source'], 'system');
      expect(server.copyArgs!['source_modified'], _systemModified);
      expect(server.copyArgs!['company'], 'دفتر نمونه');
      // The original was never saved.
      expect(server.saves, 0);
      // The copy designer opened (its subtitle is the copy title).
      expect(find.text('گردش سیستمی - کپی'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('copy failure shows the Persian reason at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = _Server()..rejectCopy = true;
      await _openList(tester, server, width);
      await _menu(tester, 'گردش سیستمی');
      await tester.tap(find.text('ایجاد کپی مستقل'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ایجاد کپی'));
      await tester.pumpAndSettle();
      expect(find.text(server.copyRejection), findsOneWidget);
      expect(server.copyArgs, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('designer of a system workflow offers a copy banner', (tester) async {
    final server = _Server();
    await tester.pumpWidget(MultiRepositoryProvider(providers: [
      RepositoryProvider<WorkflowRepository>.value(value: _DesignRepository()),
      RepositoryProvider<FrappeApiClient>.value(value: server),
    ], child: MaterialApp(
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: WorkflowDesignerPage(definition: 'system'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('کپی مستقل بسازید'), findsOneWidget);
    expect(find.text('ایجاد کپی مستقل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('designer refusal message offers the copy action', (tester) async {
    final server = _Server();
    await tester.pumpWidget(MultiRepositoryProvider(providers: [
      RepositoryProvider<WorkflowRepository>.value(value: _RefusingRepository()),
      RepositoryProvider<FrappeApiClient>.value(value: server),
    ], child: MaterialApp(
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: WorkflowDesignerPage(definition: 'system'))));
    await tester.pumpAndSettle();
    // Drive the designer's own cubit: a stage save is refused by the server
    // with the copy-required message, which the snackbar must turn into an action.
    // The page's BlocProvider owns and closes this cubit; do not close it here.
    final cubit = tester.element(find.byType(Scaffold).first)
        .read<WorkflowDesignerCubit>();
    // Do not await the save directly: in the fake-async zone its timers only
    // advance while the test pumps.
    final pending = cubit.saveStage(_systemDesign().stages.single, const {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await pending;
    await tester.pump();
    // The refusal shows in the snackbar (with the copy action) and the draft banner.
    expect(find.text(_refusal), findsWidgets);
    // The snackbar offers the copy as an action, not just the banner button.
    expect(find.byWidgetPredicate((widget) =>
        widget is SnackBarAction && widget.label == 'ایجاد کپی مستقل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
