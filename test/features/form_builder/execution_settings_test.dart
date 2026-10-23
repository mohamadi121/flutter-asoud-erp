import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/features/form_builder/execution_contract.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/execution_settings.dart';

class ExecutionClient extends Fake implements FrappeApiClient {
  int calls = 0;
  Object? failure;
  bool empty = false;
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'designer@example.com',
      fullName: 'طراح',
      roles: ['System Manager']);
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.forms.execution_kinds');
    calls++;
    if (failure != null) throw failure!;
    if (empty) {
      return {
        'message': {
          'ok': true,
          'data': [],
          'meta': {'api_version': 'v1'}
        }
      };
    }
    // Same fixture as TestFormExecution.test_catalog_rejects_employee_and_allows_designer_without_employee.
    return {
      'message': {
        'ok': true,
        'data': [
          {
            'kind': 'test_only',
            'label': 'اجرای آزمایشی',
            'parameters': {
              'amount': {
                'label': 'مبلغ',
                'types': ['Money'],
                'required': true
              },
            }
          },
        ],
        'meta': {'api_version': 'v1'}
      }
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('execution form keeps a local draft when its catalog cannot be reached', () async {
    final client = ExecutionClient()..failure = const ApiException(kind: ApiFailureKind.network, message: '');
    final repository = FormRepository(client, 'شرکت');
    final saved = await repository.save({'client_id': 'execution-local-draft', 'schema': {
      'schema_version': 2, 'kind': 'Request', 'title': 'درخواست آزمایشی',
      'execution': {'kind': 'test_only'}, 'sections': [{'id': 'main', 'title': 'اصلی', 'fields': [
        {'key': 'asked', 'label': 'مبلغ', 'type': 'Money', 'execution_key': 'amount'},
      ]}],
    }});
    expect(saved['local'], isTrue);
    expect((await repository.drafts()).single['schema']['execution'], {'kind': 'test_only'});
  });

  test('stage execution mapping survives read, copy and write', () {
    final field = WorkflowFormFieldDefinition.fromMap({
      'key': 'approved',
      'label': 'مبلغ مصوب',
      'type': 'Currency',
      'execution_key': 'amount'
    });
    expect(
        field.copyWith(label: 'مبلغ نهایی').toMap()['execution_key'], 'amount');
  });
  test(
      'execution catalog is a read and preserves the documented parameter object',
      () async {
    final repository = FormRepository(ExecutionClient(), 'شرکت');
    final kinds = await repository.executionKinds();
    expect(kinds.single['parameters'], {
      'amount': {
        'label': 'مبلغ',
        'types': ['Money'],
        'required': true
      }
    });
    expect(
        FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.forms.execution_kinds'),
        isTrue);
  });
  test('execution validation matches backend mapping errors', () {
    final catalog = <FormMap>[
      {
        'kind': 'sample',
        'parameters': {
          'amount': {
            'label': 'مبلغ',
            'types': ['Money'],
            'required': true
          }
        }
      }
    ];
    final field = <String, dynamic>{'key': 'asked', 'type': 'Money'};
    final schema = <String, dynamic>{
      'kind': 'Request',
      'execution': {'kind': 'sample'},
      'sections': [
        {
          'fields': [field]
        }
      ]
    };
    expect(executionProblems(schema, catalog),
        ['نگاشت پارامتر الزامی مشخص نشده است: مبلغ']);
    field['execution_key'] = 'amount';
    expect(executionProblems(schema, catalog), isEmpty);
    field['type'] = 'Date';
    expect(executionProblems(schema, catalog),
        ['نوع فیلد با پارامتر اجرا سازگار نیست.']);
    field['execution_key'] = 'unknown';
    expect(
        executionProblems(schema, catalog), ['پارامتر اجرای فیلد معتبر نیست.']);
  });
  testWidgets('catalog failure ends in a Persian reason and successful retry',
      (tester) async {
    const failure = ApiException(kind: ApiFailureKind.network, message: '');
    final client = ExecutionClient()..failure = failure;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExecutionSettings(
      repository: FormRepository(client, 'شرکت'),
      fields: const [],
      onChanged: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text(failureMessage(failure)), findsOneWidget);
    expect(find.text('در حال دریافت انواع اجرا…'), findsNothing);
    client.failure = null;
    client.empty = true;
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز نوع اجرایی در دسترس نیست.'), findsOneWidget);
    expect(client.calls, 2);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('execution kind and parameter selection at $width RTL',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = ExecutionClient();
      final schema = <String, dynamic>{
        'kind': 'Request',
        'sections': [
          {
            'fields': [
              <String, dynamic>{
                'key': 'asked',
                'label': 'مبلغ درخواستی',
                'type': 'Money'
              }
            ]
          },
        ]
      };
      await tester.pumpWidget(MaterialApp(
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: StatefulBuilder(
                      builder: (_, update) => ExecutionSettings(
                            repository: FormRepository(client, 'شرکت'),
                            schema: schema,
                            onChanged: () => update(() {}),
                          ))))));
      await tester.pumpAndSettle();
      expect(find.text('اجرای پس از تأیید'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('execution-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اجرای آزمایشی').last);
      await tester.pumpAndSettle();
      expect(schema['execution'], {'kind': 'test_only'});
      await tester.tap(find.byKey(const ValueKey('execution-parameter-asked')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مبلغ').last);
      await tester.pumpAndSettle();
      final fields =
          ((schema['sections'] as List).single as Map)['fields'] as List;
      expect((fields.single as Map)['execution_key'], 'amount');
      expect(client.calls, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets('stage mapping uses the same picker at $width RTL',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fields = <FormMap>[
        {'key': 'approved', 'label': 'مبلغ مصوب', 'type': 'Currency'}
      ];
      await tester.pumpWidget(MaterialApp(
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
              body: ExecutionSettings(
            repository: FormRepository(ExecutionClient(), 'شرکت'),
            fields: fields,
            onChanged: () {},
          ))));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('execution-parameter-approved')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مبلغ').last);
      await tester.pumpAndSettle();
      expect(fields.single['execution_key'], 'amount');
      expect(tester.takeException(), isNull);
    });
  }
}
