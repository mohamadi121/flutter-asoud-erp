import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/document_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeClient {}

const _prefix = 'asoud_erp.api.v1.document_templates.';

Map<String, dynamic> _templateJson() => {
      'name': 'TPL-1',
      'title': 'سند هزینه خرید',
      'module': 'Finance',
      'document_type': 'Journal Entry',
      'description': 'بر اساس درخواست خرید',
      'mapping': {
        'posting_date': {'source': 'system', 'value': 'today'},
        'amount': {'source': 'request', 'value': 'total'},
      },
      'create_as_draft': true,
      'auto_submit': false,
      'reusable': true,
      'status': 'Active',
      'kind': 'custom',
    };

void main() {
  late _Client client;
  late WorkflowAutomationRepository repository;
  late FakeLocalRecordStore local;
  late List<(String, Map<String, dynamic>)> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    calls = [];
    local = FakeLocalRecordStore();
    repository = WorkflowAutomationRepository(client, local: local);
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenReturn('http://localhost:8000');
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'operator@example.com',
            fullName: 'Operator',
            roles: ['System Manager']));
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final method = invocation.positionalArguments.first as String;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      calls.add((method, data));
      return switch (method) {
        '${_prefix}document_template_options' => {
            'modules': [
              {
                'key': 'Finance',
                'label': 'مالی',
                'description': 'حسابداری و خزانه‌داری',
                'types': [
                  {'key': 'Journal Entry', 'label': 'سند حسابداری'},
                  {'key': 'Receipt', 'label': 'دریافت', 'enabled': false},
                ],
              },
              {'key': 'HR', 'label': 'منابع انسانی', 'types': []},
            ],
            'fields': {
              'Journal Entry': [
                {
                  'key': 'amount',
                  'label': 'مبلغ',
                  'type': 'Currency',
                  'required': true
                },
                {
                  'key': 'debit_account',
                  'label': 'حساب بدهکار',
                  'type': 'Account'
                },
              ],
            },
            'sources': {
              'request': [
                {'key': 'total', 'label': 'مبلغ کل', 'type': 'Currency'}
              ],
            },
            'placeholders': ['{{RequestNo}}'],
          },
        '${_prefix}list_document_templates' => [_templateJson()],
        '${_prefix}save_document_template' => {
            ..._templateJson(),
            'name': 'TPL-2'
          },
        '${_prefix}document_template_link_options' => [
            {'value': 'Expenses - T', 'label': 'هزینه‌ها'}
          ],
        'asoud_erp.api.v1.automatic_actions.options' => {
            'schema_version': 2,
            'sources': {'stages': []},
            'execution_ready': true,
          },
        _ => {'ok': true},
      };
    });
  });

  test('automatic action options are cached per user and reused offline',
      () async {
    final online = await repository.automaticActionOptions('WF-1', 'ST-2');
    expect(online.data['schema_version'], 2);
    expect(online.fromCache, isFalse);

    when(() =>
        client.callAsoudMethod('asoud_erp.api.v1.automatic_actions.options',
            data: any(named: 'data'))).thenThrow(const ApiException(
        kind: ApiFailureKind.network, message: 'server offline'));
    final offline = await repository.automaticActionOptions('WF-1', 'ST-2');
    expect(offline.data['schema_version'], 2);
    expect(offline.fromCache, isTrue);
    expect(offline.connectionError, 'server offline');
  });

  test('offline automatic action options restore the queued save for this user',
      () async {
    await repository.automaticActionOptions('WF-1', 'ST-2');
    await local.save(
      entityType: 'asoud_erp.api.v1.automatic_actions.save',
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': 'operator@example.com',
        '_asoud_server': 'http://localhost:8000',
        'definition': 'WF-1',
        'stage': 'ST-2',
        'config': {'schema_version': 2, 'title': 'Saved offline'},
        'routes': {'Success': 'ST-3', 'Error': ''},
      },
      status: LocalSyncStatus.pendingSync,
    );
    when(() =>
        client.callAsoudMethod('asoud_erp.api.v1.automatic_actions.options',
            data: any(named: 'data'))).thenThrow(const ApiException(
        kind: ApiFailureKind.network, message: 'server offline'));

    final offline = await repository.automaticActionOptions('WF-1', 'ST-2');
    expect(offline.pendingDraft, {
      'config': {'schema_version': 2, 'title': 'Saved offline'},
      'routes': {'Success': 'ST-3', 'Error': ''},
    });
  });

  test('options parse modules, fields, sources and availability', () async {
    final options =
        await repository.templateOptions(company: 'Taban', workflow: 'WF-1');
    expect(calls.single.$2, {'company': 'Taban', 'workflow': 'WF-1'});
    final finance = options.module('Finance')!;
    expect(finance.available, isTrue);
    expect(finance.types.last.enabled, isFalse);
    expect(options.module('HR')!.available, isFalse);
    final fields = options.fields['Journal Entry']!;
    expect(fields.first.required, isTrue);
    expect(fields.last.isLink, isTrue);
    expect(options.sources['request']!.single.key, 'total');
    expect(options.typeLabel('Journal Entry'), 'سند حسابداری');
  });

  test('templates list and save send the server contract', () async {
    final rows = await repository.templates(
        company: 'Taban', kind: 'custom', search: ' خرید ');
    expect(calls.last.$2,
        {'company': 'Taban', 'kind': 'custom', 'search': 'خرید'});
    final template = rows.single;
    expect(template.mapping['amount']!.source, 'request');
    final saved = await repository.saveTemplate(
        company: 'Taban',
        template: template.copyWith(autoSubmit: true),
        sourceWorkflow: 'WF-1');
    final sent = calls.last.$2;
    expect(sent['name'], 'TPL-1');
    expect(sent['source_workflow'], 'WF-1');
    final payload = sent['template'] as Map<String, dynamic>;
    expect(payload['auto_submit'], isTrue);
    expect(payload['create_as_draft'], isFalse);
    expect(payload['mapping'], {
      'posting_date': {'source': 'system', 'value': 'today'},
      'amount': {'source': 'request', 'value': 'total'},
    });
    expect(saved.name, 'TPL-2');
  });

  test('a ready preset is saved as a new template', () async {
    const preset = DocumentTemplate(
        name: 'purchase_expense',
        title: 'سند هزینه خرید',
        module: 'Finance',
        documentType: 'Journal Entry',
        kind: 'ready',
        presetKey: 'purchase_expense');
    await repository.saveTemplate(company: 'Taban', template: preset);
    expect(calls.last.$2.containsKey('name'), isFalse);
    expect(calls.last.$2['preset_key'], 'purchase_expense');
  });

  test('routes and link options', () async {
    await repository.saveStageRoutes(
        definition: 'WF-1',
        stage: 'ST-2',
        routes: {'Approve': 'ST-3', 'Reject': ''});
    expect(calls.last.$1, 'asoud_erp.api.v1.workflow.save_stage_routes');
    expect(calls.last.$2['routes'], {'Approve': 'ST-3', 'Reject': ''});
    final accounts =
        await repository.linkOptions(company: 'Taban', targetType: 'Account');
    expect(accounts.single.label, 'هزینه‌ها');
  });
}
