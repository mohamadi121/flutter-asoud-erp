import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/stage_settings_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_form_sheet.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkflowStage _stage(String id, WorkflowStageType type, String title, int seq,
        [Map<String, dynamic> config = const {}]) =>
    WorkflowStage(
        id: id,
        key: id,
        type: type,
        title: title,
        sequence: seq,
        configurationComplete: true,
        config: config);

/// An approval stage (S2) that already has a real stage form bound to it.
WorkflowDesign _boundDesign() => WorkflowDesign(
      workflow: const WorkflowDefinition(
          id: 'WF-1',
          code: 'purchase',
          title: 'درخواست خرید',
          targetDoctype: 'ASOUD Workflow Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          company: 'تابان'),
      stages: [
        _stage('S0', WorkflowStageType.start, 'شروع', 1),
        _stage('S1', WorkflowStageType.userTask, 'ثبت درخواست', 2),
        _stage('S2', WorkflowStageType.approval, 'تأیید مدیر مستقیم', 3, {
          'assignment_type': 'Direct Manager',
          'approval_mode': 'Any',
          'supplementary_form': {
            'form': 'stage-form-1',
            'revision': 'rev-1',
            'title': 'چک‌لیست بررسی درخواست',
          },
        }),
        _stage('S3', WorkflowStageType.end, 'پایان فرایند', 4),
      ],
      transitions: const [
        WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S1'),
        WorkflowTransition(id: 'T2', fromStage: 'S1', toStage: 'S2'),
        WorkflowTransition(id: 'T3', fromStage: 'S2', toStage: 'S3'),
      ],
    );

/// An approval stage (S2) with a legacy inline form and no real binding.
WorkflowDesign _legacyDesign() => WorkflowDesign(
      workflow: const WorkflowDefinition(
          id: 'WF-1',
          code: 'purchase',
          title: 'درخواست خرید',
          targetDoctype: 'ASOUD Workflow Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          company: 'تابان'),
      stages: [
        _stage('S0', WorkflowStageType.start, 'شروع', 1),
        _stage('S1', WorkflowStageType.userTask, 'ثبت درخواست', 2),
        _stage('S2', WorkflowStageType.approval, 'تأیید مدیر مستقیم', 3, {
          'assignment_type': 'Direct Manager',
          'approval_mode': 'Any',
          'form_fields': [
            {'key': 'note', 'label': 'یادداشت', 'type': 'Text'},
            {'key': 'ok', 'label': 'تأیید', 'type': 'Text'},
          ],
        }),
        _stage('S3', WorkflowStageType.end, 'پایان فرایند', 4),
      ],
      transitions: const [
        WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S1'),
        WorkflowTransition(id: 'T2', fromStage: 'S1', toStage: 'S2'),
        WorkflowTransition(id: 'T3', fromStage: 'S2', toStage: 'S3'),
      ],
    );

/// An approval stage (S2) with no form at all, for the create flow.
WorkflowDesign _blankDesign() => WorkflowDesign(
      workflow: const WorkflowDefinition(
          id: 'WF-1',
          code: 'purchase',
          title: 'درخواست خرید',
          targetDoctype: 'ASOUD Workflow Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          company: 'تابان'),
      stages: [
        _stage('S0', WorkflowStageType.start, 'شروع', 1),
        _stage('S1', WorkflowStageType.userTask, 'ثبت درخواست', 2),
        _stage('S2', WorkflowStageType.approval, 'تأیید مدیر مستقیم', 3, {
          'assignment_type': 'Direct Manager',
          'approval_mode': 'Any',
        }),
        _stage('S3', WorkflowStageType.end, 'پایان فرایند', 4),
      ],
      transitions: const [
        WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S1'),
        WorkflowTransition(id: 'T2', fromStage: 'S1', toStage: 'S2'),
        WorkflowTransition(id: 'T3', fromStage: 'S2', toStage: 'S3'),
      ],
    );

const _options = WorkflowFormOptions(
  companies: ['تابان'],
  modules: [],
  roles: ['Accounts Manager', 'Purchase Manager'],
  departments: [
    WorkflowTargetOption(id: 'All', label: 'همه واحدها', isGroup: true),
  ],
  employees: [],
);

class _Workflows extends Fake implements WorkflowRepository {
  _Workflows(this.design);
  final WorkflowDesign design;
  final saved = <Map<String, dynamic>>[];
  @override
  Future<WorkflowDesign> getDesign(String definition) async => design;
  @override
  Future<WorkflowFormOptions> getFormOptions() async => _options;
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved.add(config);
    return design;
  }
}

/// Records every form API call so a test can prove no delete/save happened.
/// Also answers the editor's save/publish calls so a form can be published.
class _FormClient extends Fake implements FrappeApiClient {
  final calls = <String>[];
  final saveFormNames = <String>[];
  // The last saved schema, echoed back by `transition` like the real backend.
  Map<String, dynamic>? lastSchema;
  // When true, open_builtin fails so a test can check the error path.
  bool failOpenBuiltin = false;
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'designer', fullName: 'طراح', roles: ['System Manager']);
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    calls.add(method.split('.').last);
    if (method.endsWith('list_forms')) {
      // The stage form sheet lists the company's stage forms plus the defaults.
      return {
        'message': {
          'ok': true,
          'data': [
            {
              'name': 'stage-form-1',
              'title': 'چک‌لیست بررسی درخواست',
              'kind': 'Stage',
              'builtin_key': 'stage_request_checklist',
              'active_revision': 'rev-1',
            },
            {
              'name': 'stage-form-2',
              'title': 'فرم بررسی مالی',
              'kind': 'Stage',
              'active_revision': 'rev-2',
            },
          ]
        }
      };
    }
    if (method.endsWith('open_builtin')) {
      if (failOpenBuiltin) {
        throw const ApiException(
            kind: ApiFailureKind.server,
            message: 'ارتباط با سرور برقرار نشد.');
      }
      return {
        'message': {
          'ok': true,
          'data': {
            'name': 'stage-form-1',
            'active_revision': 'rev-1',
            'schema': {
              'kind': 'Stage',
              'title': 'چک‌لیست بررسی درخواست',
              'sections': [
                {
                  'id': 'main',
                  'fields': [
                    {'key': 'note', 'label': 'یادداشت', 'type': 'Text'}
                  ]
                }
              ]
            }
          }
        }
      };
    }
    if (method.endsWith('get_options')) {
      return {
        'message': {
          'ok': true,
          'data': {
            'roles': ['System Manager'],
            'departments': <String>[],
            'workflows': <Map<String, dynamic>>[],
            'can_publish': true,
          }
        }
      };
    }
    if (method.endsWith('get_form')) {
      final name = '${data?['name']}';
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': {
            'name': name,
            'active_revision': name == 'stage-form-2' ? 'rev-2' : 'rev-1',
            // Only the default form is a builtin; a custom form is not.
            if (name == 'stage-form-1')
              'builtin_key': 'stage_request_checklist',
            'schema': {
              'kind': 'Stage',
              'title': 'چک‌لیست بررسی درخواست',
              'sections': [
                {
                  'id': 'main',
                  'fields': [
                    {'key': 'note', 'label': 'یادداشت', 'type': 'Text'}
                  ]
                }
              ]
            }
          }
        }
      };
    }
    if (method.endsWith('copy_form')) {
      return {
        'message': {
          'ok': true,
          'data': {
            'name': 'stage-form-copy',
            'active_revision': 'rev-copy',
            'draft_version': 1,
            'schema': {
              'kind': 'Stage',
              'title': 'چک‌لیست بررسی درخواست - نسخه اختصاصی',
              'sections': [
                {
                  'id': 'main',
                  'fields': [
                    {'key': 'note', 'label': 'یادداشت', 'type': 'Text'}
                  ]
                }
              ]
            }
          }
        }
      };
    }
    if (method.endsWith('save_form')) {
      final name = '${data?['name'] ?? 'stage-form-new'}';
      saveFormNames.add(name);
      lastSchema = Map<String, dynamic>.from(jsonDecode('${data?['schema']}'));
      return {
        'message': {
          'ok': true,
          'data': {
            'name': name,
            'status': 'Draft',
            'draft_version': 1,
            'schema': lastSchema,
          }
        }
      };
    }
    if (method.endsWith('transition')) {
      // The real backend returns row(doc, schema=True): name, active_revision
      // and the published schema. The editor binds from exactly these keys.
      return {
        'message': {
          'ok': true,
          'data': {
            'name': data?['name'],
            'status': 'Published',
            'active_revision': 'rev-1',
            'draft_version': 2,
            'schema': lastSchema,
          }
        }
      };
    }
    return {
      'message': {'ok': true, 'data': <Map<String, dynamic>>[]}
    };
  }
}

class _Automation extends Fake implements WorkflowAutomationRepository {
  @override
  final _FormClient client = _FormClient();
  @override
  bool get isLocal => false;
  final routes = <Map<String, String>>[];
  @override
  Future<void> saveStageRoutes(
      {required String definition,
      required String stage,
      required Map<String, String> routes}) async {
    this.routes.add(routes);
  }
}

Future<(_Workflows, _Automation)> _open(
    WidgetTester tester, WorkflowDesign design) async {
  final workflows = _Workflows(design);
  final automation = _Automation();
  final cubit =
      WorkflowDesignerCubit(repository: workflows, definition: 'WF-1');
  await cubit.load();
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: BlocProvider.value(
      value: cubit,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: StageSettingsPage(
                              stage: design.stages
                                  .firstWhere((stage) => stage.id == 'S2'),
                              design: design,
                              options: _options,
                              automation: automation)))),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
  return (workflows, automation);
}

/// The [TextFormField] whose decoration label is [label].
Finder _fieldByLabel(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(TextFormField))
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 20; attempt++) {
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) break;
    await tester.drag(lists.last, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('bound stage form shows its title and saves the binding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, _boundDesign());
    // The bound title is shown in the picker, not a legacy «N فیلد» label.
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    expect(find.textContaining('فرم تکمیلی ·'), findsNothing);
    // Bound form offers preview / edit / change / remove, not the legacy row.
    expect(find.text('پیش‌نمایش'), findsOneWidget);
    expect(find.text('ویرایش فرم'), findsOneWidget);
    expect(find.text('تغییر فرم'), findsOneWidget);
    expect(find.text('برداشتن فرم'), findsOneWidget);
    expect(find.text('حذف فرم'), findsNothing);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['supplementary_form'], {
      'form': 'stage-form-1',
      'revision': 'rev-1',
      'title': 'چک‌لیست بررسی درخواست',
    });
    // A bound form and legacy inline fields are mutually exclusive.
    expect(config['form_fields'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the bound form clears only the binding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _boundDesign());
    await _tap(tester, find.text('برداشتن فرم'));
    expect(find.textContaining('فرم تکمیلی از این مرحله برداشته شود؟'),
        findsOneWidget);
    // Confirm with the dialog's own button, not the page's.
    await _tap(tester, find.widgetWithText(FilledButton, 'برداشتن فرم'));
    // The picker is empty again and the bound title is gone.
    expect(find.text('چک‌لیست بررسی درخواست'), findsNothing);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['supplementary_form'], isNull);
    expect(config['form_fields'], isEmpty);
    // Removing a binding never deletes the form or its revisions.
    expect(automation.client.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy inline form is shown and saved unchanged',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, _legacyDesign());
    // The legacy «N فیلد» label is kept for an unbound inline form.
    expect(find.textContaining('فرم تکمیلی ·'), findsOneWidget);
    expect(find.text('ویرایش فرم'), findsOneWidget);
    expect(find.text('حذف فرم'), findsOneWidget);
    expect(find.text('پیش‌نمایش'), findsNothing);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['supplementary_form'], isNull);
    expect((config['form_fields'] as List).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a stage form publishes it and binds it automatically',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _blankDesign());
    // Open the picker and choose to create a custom form.
    await _tap(tester, find.text('انتخاب یا ویرایش فرم مرحله'));
    await _tap(tester, find.text('ساخت فرم اختصاصی'));
    // The existing form editor opens for a new Stage form.
    expect(find.byType(FormEditorPage), findsOneWidget);
    // Give the form a title.
    await _tap(tester, find.byType(FormSpecCard));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('عنوان فرم *'), 'فرم بررسی مالی');
    // Close the info sheet (the title is applied on change).
    await _tap(tester, find.byIcon(Icons.close));
    // Add one field so the schema is valid.
    await _tap(tester, find.text('افزودن فیلد'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('عنوان فیلد *'), 'مبلغ');
    await _tap(tester, find.text('تأیید و افزودن'));
    // Publish from the preview step.
    await _tap(tester, find.text('پیش‌نمایش'));
    await _tap(tester, find.text('ذخیره و انتشار'));
    await _tap(tester, find.text('انتشار فرم'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('تأیید'));
    // Leave preview mode, then go back: the editor returns the published record.
    await _tap(tester, find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    // The editor returns the published record and the stage binds it.
    expect(find.byType(FormEditorPage), findsNothing);
    expect(find.text('فرم بررسی مالی'), findsOneWidget);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    final binding = config['supplementary_form'];
    expect(binding, isA<Map>());
    expect(binding['form'], 'stage-form-new');
    expect(binding['revision'], 'rev-1');
    expect(binding['title'], 'فرم بررسی مالی');
    expect(config['form_fields'], isEmpty);
    // The new form was saved and published, never a delete.
    expect(automation.client.saveFormNames, contains('stage-form-new'));
    expect(automation.client.calls, contains('transition'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a default form copies it and never saves the original',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _boundDesign());
    // The bound form's own edit button opens the editor (or a copy).
    await _tap(tester, find.text('ویرایش فرم'));
    // The default form is copied first so the original is never changed.
    expect(automation.client.calls, contains('copy_form'));
    expect(find.byType(FormEditorPage), findsOneWidget);
    // Cancel: the stage keeps its previous binding unchanged.
    await _tap(tester, find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(FormEditorPage), findsNothing);
    // No save was made on the original or the copy.
    expect(automation.client.saveFormNames, isEmpty);
    // The bound title is still shown.
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- PART B: the stage form sheet -------------------------------------------------------

  /// Taps a form card inside the open stage form sheet, by its title.
  Future<void> tapCard(WidgetTester tester, String title) async {
    await tester.tap(find.descendant(
        of: find.byType(StageFormSheet), matching: find.text(title)));
    await tester.pumpAndSettle();
  }

  testWidgets('picking a default form calls open_builtin and binds it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _blankDesign());
    await _tap(tester, find.text('انتخاب یا ویرایش فرم مرحله'));
    // The sheet lists the defaults; pick the built-in checklist.
    await tapCard(tester, 'چک‌لیست بررسی درخواست');
    expect(automation.client.calls, contains('open_builtin'));
    // The bound title is now shown in the picker.
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    final binding = config['supplementary_form'];
    expect(binding, isA<Map>());
    expect(binding['form'], 'stage-form-1');
    expect(binding['revision'], 'rev-1');
    expect(config['form_fields'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking an existing form calls get_form and binds its revision',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _blankDesign());
    await _tap(tester, find.text('انتخاب یا ویرایش فرم مرحله'));
    // A non-builtin company form is resolved with get_form.
    await tapCard(tester, 'فرم بررسی مالی');
    expect(automation.client.calls, contains('get_form'));
    expect(automation.client.calls, isNot(contains('open_builtin')));
    await _tap(tester, find.text('ذخیره'));
    final binding = workflows.saved.single['supplementary_form'];
    expect(binding, isA<Map>());
    expect(binding['form'], 'stage-form-2');
    expect(binding['revision'], 'rev-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening the picker keeps the saved binding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, _boundDesign());
    // The saved binding is shown on load.
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    // Open the picker and close it without choosing anything.
    await _tap(tester, find.text('چک‌لیست بررسی درخواست'));
    await tester.pumpAndSettle();
    expect(find.byType(StageFormSheet), findsOneWidget);
    await _tap(tester,
        find.descendant(of: find.byType(StageFormSheet),
            matching: find.byIcon(Icons.close_rounded)));
    // The binding is unchanged after reopening.
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    await _tap(tester, find.text('ذخیره'));
    final binding = workflows.saved.single['supplementary_form'];
    expect(binding, isA<Map>());
    expect(binding['form'], 'stage-form-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the editor leaves the previous binding unchanged',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, _blankDesign());
    await _tap(tester, find.text('انتخاب یا ویرایش فرم مرحله'));
    await _tap(tester, find.text('ساخت فرم اختصاصی'));
    expect(find.byType(FormEditorPage), findsOneWidget);
    // Cancel without saving: the editor pops null.
    await _tap(tester, find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(FormEditorPage), findsNothing);
    // No form was bound; the picker is still empty.
    expect(find.text('انتخاب یا ویرایش فرم مرحله'), findsOneWidget);
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['supplementary_form'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed open_builtin shows a message and keeps the binding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, _boundDesign());
    automation.client.failOpenBuiltin = true;
    // Open the picker and pick the built-in form; open_builtin will fail.
    await _tap(tester, find.text('چک‌لیست بررسی درخواست'));
    await tester.pumpAndSettle();
    await tapCard(tester, 'چک‌لیست بررسی درخواست');
    // A Persian failure message is shown (the server-error sentence).
    expect(
        find.textContaining('خطایی در سرور رخ داد'), findsOneWidget);
    // The previous binding is unchanged.
    await _tap(tester, find.text('ذخیره'));
    final binding = workflows.saved.single['supplementary_form'];
    expect(binding, isA<Map>());
    expect(binding['form'], 'stage-form-1');
    expect(tester.takeException(), isNull);
  });
}
