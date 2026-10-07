import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/document_template.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/request_flow_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';

/// No session: the app runs as the offline preview.
class _Client extends Mock implements FrappeApiClient {}

class _Offline extends Fake implements WorkflowRepository {
  static const error =
      ApiException(kind: ApiFailureKind.network, message: 'offline');
  @override
  Future<WorkflowDesign> getDesign(String definition) async => throw error;
  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) async =>
      throw error;
}

void main() {
  late _Client client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  test('document templates are kept on the device without a session', () async {
    final repository = WorkflowAutomationRepository(client);
    expect(repository.isLocal, isTrue);
    final options = await repository.templateOptions(company: 'دفتر نمونه');
    expect(options.module('Finance')!.available, isTrue);
    expect(options.fields['Journal Entry']!.length, 8);
    expect(options.sources['request']!.first.key, 'request_number');
    final ready =
        await repository.templates(company: 'دفتر نمونه', kind: 'ready');
    expect(ready.first.isReady, isTrue);
    expect(ready.map((row) => row.title), contains('سند هزینه خرید'));
    final accounts = await repository.linkOptions(
        company: 'دفتر نمونه', targetType: 'Account', txt: 'بانک');
    expect(accounts.single.label, 'بانک');

    final saved = await repository.saveTemplate(
        company: 'دفتر نمونه',
        template: ready.first.copyWith(mapping: {
          ...ready.first.mapping,
          'amount': const ValueSource(source: 'fixed', value: '1000'),
        }));
    expect(saved.name, startsWith('LOCAL-TPL-'));
    expect(saved.isReady, isFalse);
    // Templates are per device in the preview, whatever office is chosen.
    final custom = await repository.templates(company: 'دیگر');
    expect(custom.single.mapping['amount']!.value, '1000');
    expect((await repository.template(saved.name)).title, 'سند هزینه خرید');
    await repository.setTemplateStatus(saved.name, 'Inactive');
    expect((await repository.template(saved.name)).isActive, isFalse);
    final renamed = await repository.saveTemplate(
        company: 'دفتر نمونه',
        template: custom.single.copyWith(title: 'سند جدید'));
    expect(renamed.name, saved.name);
    expect((await repository.templates(company: 'x')).single.title, 'سند جدید');
    verifyNever(() => client.callAsoudMethod(any(), data: any(named: 'data')));
  });

  test('stage routes are saved on the local design', () async {
    final repository = PreviewFallbackWorkflowRepository(_Offline());
    var design = await repository.addStage(
        definition: 'PREVIEW-WF-001',
        afterStage: 'PREVIEW-WF-001-START',
        type: WorkflowStageType.approval);
    final approval =
        design.stages.firstWhere((s) => s.type == WorkflowStageType.approval);
    design = await repository.addStage(
        definition: 'PREVIEW-WF-001',
        afterStage: approval.id,
        type: WorkflowStageType.end);
    final end =
        design.stages.firstWhere((s) => s.type == WorkflowStageType.end);
    design = await repository.saveStageRoutesLocally(
        definition: 'PREVIEW-WF-001',
        stage: approval.id,
        routes: {'Approve': end.id, 'Reject': end.id});
    var routes = design.transitions.where((e) => e.fromStage == approval.id);
    expect(routes.map((e) => e.condition['action']).toSet(),
        {'Approve', 'Reject'});
    expect(routes.map((e) => e.label).toSet(), {'تأیید', 'رد'});
    design = await repository.saveStageRoutesLocally(
        definition: 'PREVIEW-WF-001',
        stage: approval.id,
        routes: {'Reject': ''});
    routes = design.transitions.where((e) => e.fromStage == approval.id);
    expect(routes.single.condition['action'], 'Approve');
    // The saved design survives a restart of the repository.
    final reloaded = PreviewFallbackWorkflowRepository(_Offline());
    final again = await reloaded.getDesign('PREVIEW-WF-001');
    expect(
        again.transitions
            .where((e) => e.fromStage == approval.id)
            .single
            .toStage,
        end.id);
  });

  test('requests are created and read on the device without a session',
      () async {
    final store = FakeLocalRecordStore();
    final repository =
        GenericRequestRepository(client, 'دفتر نمونه', store: store);
    final types = await repository.options();
    final sample = types.firstWhere((row) => row['name'] == 'DEMO-WF-MISSION');
    expect(sample['workflow_title'], 'درخواست مأموریت');
    expect((await repository.fieldOptions('Item')).first['label'], 'لپ‌تاپ');
    expect(
        (await repository.fieldOptions('UOM', itemCode: 'PREVIEW-PAPER'))
            .single['value'],
        'بسته');

    final created = await repository.create({
      'workflow_definition': sample['name'],
      'subject': 'خرید لپ‌تاپ',
      'values': {
        'destination': 'تهران',
        'items': [
          {'item_code': 'PREVIEW-LAPTOP', 'qty': 2, 'uom': 'عدد'}
        ]
      },
      'attachments': const [],
    }, 'request-local-000001');
    expect(created!['local_preview'], isTrue);
    expect('${created['local_number']}', startsWith('LOCAL-'));
    expect(requestStatus(created).$1, 'ذخیره روی گوشی');
    expect(
        (await store.list(entityType: 'generic_request_outbox')).single.status,
        LocalSyncStatus.localOnly);
    final rows = await repository.list();
    expect(rows.single['subject'], 'خرید لپ‌تاپ');
    expect(rows.single['local_preview'], isTrue);
    final detail = await repository.detail('${created['name']}');
    expect(detail['values']['destination'], 'تهران');
    await repository.sync(retry: true);
    verifyNever(() => client.callAsoudMethod(any(), data: any(named: 'data')));
    verifyNever(() => client.getCurrentUser());
  });

  test('a request type designed on the device is offered offline', () async {
    SharedPreferences.setMockInitialValues({
      'asoud_workflow_designs_v2':
          '[{"workflow":{"id":"LOCAL-WF-1","title":"درخواست مرخصی","target_doctype":"ASOUD Workflow Request","icon_key":"leave"},'
              '"stages":[{"id":"S0","type":"start","config":{}},{"id":"S1","type":"userTask","config":{"form_fields":[{"key":"days","label":"تعداد روز","type":"Number","required":true}]}}],'
              '"transitions":[{"from":"S0","to":"S1"}]}]'
    });
    final repository = GenericRequestRepository(client, 'دفتر نمونه',
        store: FakeLocalRecordStore());
    final types = await repository.options();
    expect(types.first['workflow_title'], 'درخواست مرخصی');
    expect((types.first['fields'] as List).single['key'], 'days');
    final options = await WorkflowAutomationRepository(client)
        .templateOptions(company: 'x', workflow: 'LOCAL-WF-1');
    expect(options.sources['request']!.map((row) => row.key), contains('days'));
  });
}
