import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/receipt_confirmation_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

// Copied from the backend contract (docs/api/form-execution.md, request_followup).
const _confirmed = {
  'task': 'WFT-1',
  'status': 'Completed',
  'movement': {'doctype': 'Asset Movement', 'name': 'ACC-ASM-1', 'docstatus': 1},
};

void main() {
  late _MockClient client;
  setUp(() => client = _MockClient());

  test('confirm calls the confirm endpoint with only the task', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _confirmed);
    await FrappeReceiptConfirmationRepository(client).confirm('WFT-1');
    verify(() => client.callAsoudMethod(
        'asoud_erp.api.v1.request_followup.confirm_receipt',
        data: {'task': 'WFT-1'})).called(1);
  });

  test('reject sends the trimmed reason to the reject endpoint', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {..._confirmed, 'status': 'Rejected'});
    await FrappeReceiptConfirmationRepository(client)
        .reject('WFT-1', '  تجهیز تحویل نشد  ');
    verify(() => client.callAsoudMethod(
        'asoud_erp.api.v1.request_followup.reject_receipt',
        data: {'task': 'WFT-1', 'reason': 'تجهیز تحویل نشد'})).called(1);
  });

  test('task list rows carry the follow-up kind, empty for other tasks',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'items': [
                {
                  'name': 'WFT-1',
                  'workflow_instance': 'WFI-1',
                  'workflow_stage': 'S-END',
                  'task_title': 'تأیید دریافت تجهیز: لپ‌تاپ',
                  'status': 'Open',
                  'followup': 'confirm_receipt',
                },
                {
                  'name': 'WFT-2',
                  'workflow_instance': 'WFI-2',
                  'workflow_stage': 'S-2',
                  'task_title': 'بررسی',
                  'status': 'Open',
                  'followup': null,
                },
              ],
              'next_cursor': null,
            });
    final tasks = await FrappeWorkflowTaskRepository(client).getMyTasks();
    expect(tasks.map((task) => task.followup), ['confirm_receipt', '']);
  });

  test('task detail of a receipt task exposes the asset rows', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'name': 'WFT-1',
              'workflow_instance': 'WFI-1',
              'workflow_stage': 'S-END',
              'request_name': 'REQ-1',
              'request_company': 'شرکت',
              'task_title': 'تأیید دریافت تجهیز: لپ‌تاپ',
              'status': 'Open',
              'stage_type': 'User Task',
              'config': {
                'activity_type': 'ConfirmReceipt',
                'allow_reject': true,
                'allow_return': false,
                'comment_required': false,
                'form_fields': [],
              },
              'draft': {},
              'response': {},
              'history': [],
              'previous_data': [],
              'document': {
                'doctype': 'Asset Movement',
                'name': 'ACC-ASM-1',
                'values': [
                  {'key': 'asset', 'label': 'تجهیز', 'value': 'لپ‌تاپ', 'read_only': true},
                  {'key': 'movement_status', 'label': 'وضعیت', 'value': 'پیش‌نویس', 'read_only': true},
                ],
              },
              'request_values': {},
            });
    final detail = await FrappeWorkflowTaskRepository(client).getTask('WFT-1');
    expect(detail.activityType, 'ConfirmReceipt');
    expect(detail.documentValues.map((value) => value.value),
        ['لپ‌تاپ', 'پیش‌نویس']);
  });
}
