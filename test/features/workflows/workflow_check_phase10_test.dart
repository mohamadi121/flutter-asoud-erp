import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/data/workflow_check_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _designId = 'WF-CHECK-1';

WorkflowDesign _design() => WorkflowDesign(
      workflow: const WorkflowDefinition(
        id: _designId,
        code: 'CHK-1',
        title: 'گردش آزمایشی',
        targetDoctype: 'ASOUD Workflow Request',
        status: WorkflowDefinitionStatus.inactive,
        isLocked: true,
        version: 1,
        stepsCount: 3,
        modified: null,
      ),
      stages: const [
        WorkflowStage(
            id: 'start',
            key: 'start',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 0,
            configurationComplete: true),
        WorkflowStage(
            id: 'approve',
            key: 'approve',
            type: WorkflowStageType.approval,
            title: 'تأیید مدیر',
            sequence: 1,
            configurationComplete: true),
        WorkflowStage(
            id: 'end',
            key: 'end',
            type: WorkflowStageType.end,
            title: 'پایان',
            sequence: 2,
            configurationComplete: true),
      ],
      transitions: const [
        WorkflowTransition(
            id: 'r1', fromStage: 'start', toStage: 'approve', label: ''),
        WorkflowTransition(
            id: 'r2', fromStage: 'approve', toStage: 'end', label: ''),
      ],
    );

class _DesignRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<WorkflowDesign> getDesign(String definition) async => _design();
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: ['دفتر نمونه'], modules: []);
}

class _OfflineRepository extends _DesignRepository implements OfflinePreviewAware {
  @override
  bool get isOfflinePreview => true;
}

/// Fake server whose responses are copied from the backend contract
/// (validate_workflow / simulate_workflow, PR #57).
class _Server extends Fake implements FrappeApiClient {
  _Server({required this.validateResult, required this.simulate});

  final Map<String, dynamic> validateResult;
  final Map<String, dynamic> Function(List<Map<String, String>>) simulate;
  final decisionsSent = <List<Map<String, String>>>[];
  int validates = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'admin', fullName: 'مدیر', roles: ['System Manager']);

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == WorkflowCheckRepository.validateMethod) {
      validates++;
      return validateResult;
    }
    if (method == WorkflowCheckRepository.simulateMethod) {
      final decisions = (data!['decisions'] as List)
          .map((value) => Map<String, String>.from(value as Map))
          .toList();
      decisionsSent.add(decisions);
      return simulate(decisions);
    }
    throw StateError('unexpected method: $method');
  }
}

Map<String, dynamic> _issuesResult({
  bool ok = false,
  List<Map<String, dynamic>> issues = const [],
}) =>
    {'ok': ok, 'issues': issues};

Map<String, dynamic> _simulate({
  required List<Map<String, dynamic>> steps,
  required String status,
  String? waitingStage,
  List<String> allowedActions = const [],
  String? outcome,
  List<String> errors = const [],
}) =>
    {
      'steps': steps,
      'status': status,
      'waiting_stage': waitingStage,
      'allowed_actions': allowedActions,
      'outcome': outcome,
      'errors': errors,
    };

Future<void> _openDesigner(
    WidgetTester tester, WorkflowRepository repository, _Server server) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MultiRepositoryProvider(providers: [
    RepositoryProvider<WorkflowRepository>.value(value: repository),
    RepositoryProvider<FrappeApiClient>.value(value: server),
  ], child: MaterialApp(
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: WorkflowDesignerPage(definition: _designId))));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  test('validate_workflow is treated as a read-only method', () {
    expect(FrappeClient.isReadOnlyMethod(
        'asoud_erp.api.v1.workflow.validate_workflow'), isTrue);
  });

  testWidgets('gear opens the three-item menu at 320 px', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MultiRepositoryProvider(providers: [
      RepositoryProvider<WorkflowRepository>.value(value: _DesignRepository()),
      RepositoryProvider<FrappeApiClient>.value(
          value: _Server(
              validateResult: _issuesResult(ok: true),
              simulate: (d) => _simulate(steps: [], status: 'needs_decision'))),
    ], child: MaterialApp(
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: WorkflowDesignerPage(definition: _designId))));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش تنظیمات گردش کار'), findsOneWidget);
    expect(find.text('بررسی اعتبار گردش کار'), findsOneWidget);
    expect(find.text('اجرای آزمایشی فرایند'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('check sheet shows errors before warnings and highlights the stage',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    final server = _Server(
      validateResult: _issuesResult(
        ok: false,
        issues: [
          {
            'code': 'stage_invalid',
            'severity': 'error',
            'message': 'تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.',
            'stage': 'approve',
            'route': null,
          },
          {
            'code': 'self_loop',
            'severity': 'warning',
            'message': 'یک مرحله به خودش برمی‌گردد.',
            'stage': null,
            'route': null,
          },
        ],
      ),
      simulate: (d) => _simulate(steps: [], status: 'needs_decision'),
    );
    await _openDesigner(tester, _DesignRepository(), server);
    await _openMenu(tester, 'بررسی اعتبار گردش کار');
    await tester.pumpAndSettle();
    expect(server.validates, 1);
    expect(
        find.text('گردش‌کار هنوز قابل اجرا نیست؛ موارد زیر را برطرف کنید.'),
        findsOneWidget);
    expect(find.text('خطاها'), findsOneWidget);
    expect(find.text('هشدارها'), findsOneWidget);
    expect(
        find.text('تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.'),
        findsOneWidget);
    // The error comes before the warning in the list.
    expect(
      tester
          .getCenter(find.text(
              'تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.'))
          .dy,
      lessThan(tester.getCenter(find.text('یک مرحله به خودش برمی‌گردد.')).dy),
    );
    // Tapping the error highlights its stage on the diagram.
    await tester.tap(find.text(
        'تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.'));
    await tester.pumpAndSettle();
    final ring = tester
        .widgetList<Container>(find.descendant(
            of: find.byKey(const ValueKey('workflow-node-approve')),
            matching: find.byType(Container)))
        .map((node) => node.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    expect(ring.border, isA<Border>());
    expect((ring.border! as Border).top.color, AsoudColors.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('check sheet shows the success line when ok', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    final server = _Server(
        validateResult: _issuesResult(ok: true),
        simulate: (d) => _simulate(steps: [], status: 'needs_decision'));
    await _openDesigner(tester, _DesignRepository(), server);
    await _openMenu(tester, 'بررسی اعتبار گردش کار');
    await tester.pumpAndSettle();
    expect(find.text('گردش‌کار معتبر است و برای اجرا آماده است.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dry run walks the decisions and shows the outcome',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    final server = _Server(
      validateResult: _issuesResult(ok: true),
      simulate: (decisions) {
        if (decisions.isEmpty) {
          return _simulate(
            steps: [
              {'stage': 'start', 'title': 'شروع', 'stage_type': 'Start',
                  'action': null, 'next': 'approve'},
              {'stage': 'approve', 'title': 'تأیید مدیر',
                  'stage_type': 'Approval', 'action': null, 'next': null},
            ],
            status: 'needs_decision',
            waitingStage: 'approve',
            allowedActions: ['Approve', 'Reject', 'Return'],
          );
        }
        return _simulate(
          steps: [
            {'stage': 'start', 'title': 'شروع', 'stage_type': 'Start',
                'action': null, 'next': 'approve'},
            {'stage': 'approve', 'title': 'تأیید مدیر',
                'stage_type': 'Approval', 'action': 'Approve', 'next': 'end'},
            {'stage': 'end', 'title': 'پایان', 'stage_type': 'End',
                'action': null, 'next': null},
          ],
          status: 'finished',
          outcome: 'Completed',
        );
      },
    );
    await _openDesigner(tester, _DesignRepository(), server);
    await _openMenu(tester, 'اجرای آزمایشی فرایند');
    await tester.pumpAndSettle();
    expect(
        find.text('این فقط یک شبیه‌سازی است؛ هیچ درخواست، وظیفه یا اعلانی ایجاد نمی‌شود.'),
        findsOneWidget);
    expect(find.text('تصمیم این مرحله را انتخاب کنید'), findsOneWidget);
    expect(find.text('تأیید'), findsOneWidget);
    expect(find.text('رد'), findsOneWidget);
    expect(find.text('بازگشت برای اصلاح'), findsOneWidget);
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();
    expect(server.decisionsSent.last, [
      {'stage': 'approve', 'action': 'Approve'}
    ]);
    expect(find.text('نتیجهٔ فرایند: تکمیل‌شده'), findsOneWidget);
    expect(find.text('اجرای دوباره'), findsOneWidget);
    // Restarting resets the decisions.
    await tester.scrollUntilVisible(find.text('اجرای دوباره'), 60,
        scrollable: find.descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable)));
    await tester.tap(find.text('اجرای دوباره'));
    await tester.pumpAndSettle();
    expect(server.decisionsSent.last, isEmpty);
    expect(find.text('تصمیم این مرحله را انتخاب کنید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline preview offers the server-only notice for both actions',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    final server = _Server(
        validateResult: _issuesResult(ok: true),
        simulate: (d) => _simulate(steps: [], status: 'needs_decision'));
    await _openDesigner(tester, _OfflineRepository(), server);
    await _openMenu(tester, 'بررسی اعتبار گردش کار');
    await tester.pumpAndSettle();
    expect(
        find.text('این قابلیت برای بررسی نسخهٔ ذخیره‌شده به سرور نیاز دارد و در پیش‌نمایش آفلاین در دسترس نیست.'),
        findsOneWidget);
    expect(server.validates, 0);
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    await _openMenu(tester, 'اجرای آزمایشی فرایند');
    await tester.pumpAndSettle();
    expect(
        find.text('این قابلیت برای بررسی نسخهٔ ذخیره‌شده به سرور نیاز دارد و در پیش‌نمایش آفلاین در دسترس نیست.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
