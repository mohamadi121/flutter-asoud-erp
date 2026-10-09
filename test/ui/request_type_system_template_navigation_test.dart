import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_type_builder_page.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _WorkflowClient extends Fake implements FrappeApiClient {
  final calls = <String>[];

  static final workflow = <String, dynamic>{
    'name': 'WF-SUPPLY',
    'workflow_code': 'SUPPLY',
    'workflow_title': 'درخواست تأمین کالا / خدمت',
    'target_doctype': 'ASOUD Workflow Request',
    'status': 'Active',
    'readiness_status': 'Ready',
    'is_locked': 0,
    'is_system_template': 1,
    'template_key': 'supply',
    'version_no': 1,
    'steps_count': 1,
    'missing_requirements': <dynamic>[],
    'request_category': 'Purchase',
    'show_in_request_list': 1,
    'allow_user_submission': 1,
  };

  static final design = <String, dynamic>{
    'workflow': workflow,
    'stages': [
      {
        'name': 'STAGE-START',
        'stage_key': 'start',
        'stage_type': 'Start',
        'stage_title': 'شروع',
        'sequence_no': 0,
        'configuration_status': 'Complete',
        'config': <String, dynamic>{},
      },
      {
        'name': 'STAGE-FORM',
        'stage_key': 'form',
        'stage_type': 'User Task',
        'stage_title': 'تکمیل فرم درخواست',
        'sequence_no': 1,
        'configuration_status': 'Complete',
        'config': {
          'assignment_type': 'Initiator',
          'form_fields': [
            {
              'key': 'required_date',
              'label': 'تاریخ مورد نیاز',
              'type': 'Date',
              'required': true,
            },
          ],
        },
      },
    ],
    'transitions': [
      {
        'name': 'TRANSITION-1',
        'from_stage': 'STAGE-START',
        'to_stage': 'STAGE-FORM',
        'condition': <String, dynamic>{},
      },
    ],
  };

  dynamic _data(Map<String, dynamic> response) =>
      (response['message'] as Map<String, dynamic>)['data'];

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    calls.add(method);
    final payload = switch (method) {
      'asoud_erp.api.v1.workflow.list_workflows' => [workflow],
      'asoud_erp.api.v1.workflow.get_workflow_design' => design,
      'asoud_erp.api.v1.workflow.update_request_type_info' => workflow,
      _ => throw StateError('Unexpected workflow API method: $method'),
    };
    return _data({
      'message': {
        'ok': true,
        'data': payload,
        'meta': {'api_version': 'v1'},
      },
    });
  }
}

void main() {
  testWidgets(
      'دکمه ادامه و چیپ پیش‌نمایش فرم سیستمی را بدون ذخیره ممنوع باز می‌کنند',
      (tester) async {
    final client = _WorkflowClient();
    final repository = FrappeWorkflowRepository(client);
    final workflow = (await repository.getWorkflows()).single;
    expect(workflow.isSystemTemplate, isTrue);

    await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RequestTypeBuilderPage(existing: workflow),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();
    expect(find.text('فرم درخواست'), findsOneWidget);

    await tester.tap(find.text('پیش‌نمایش'));
    await tester.pumpAndSettle();
    expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);

    await tester.tap(find.text('بازگشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();
    expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);

    await tester.tap(find.text('ذخیره و پایان'));
    await tester.pumpAndSettle();
    expect(find.byType(RequestTypeBuilderPage), findsNothing);
    expect(client.calls,
        isNot(contains('asoud_erp.api.v1.workflow.save_stage_settings')));
  });
}
