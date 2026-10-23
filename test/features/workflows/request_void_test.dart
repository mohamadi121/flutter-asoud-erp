import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/request_void_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

// Shape of `get_request.execution` after the backend change
// (docs/api/form-execution.md «Void and reissue»).
Map<String, dynamic> _execution(String state, String label,
        {bool canVoid = false, bool canReissue = false, Map? voided}) =>
    {
      'state': state,
      'label': label,
      'error': '',
      'executed_on': state == 'succeeded' ? '2026-10-07 09:30:00' : '',
      'executed_by_name': state == 'succeeded' ? 'علی رضایی' : '',
      'reference': state == 'succeeded' ? 'HR-EA-0001' : '',
      'can_void': canVoid,
      'can_reissue': canReissue,
      if (voided != null) 'void': voided,
    };

const _reason = 'سند به اشتباه صادر شده است.';

Map<String, dynamic> _request(Map<String, dynamic> execution) => {
      ...Map<String, dynamic>.from(requestData('get_request_purchase') as Map),
      'status_key': 'approved',
      'status_label': 'تأیید شده',
      'status': 'Completed',
      'can_edit': false,
      'can_cancel': false,
      'execution': execution,
    };

class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.current);
  Map<String, dynamic> current;
  @override
  Future<Map<String, dynamic>> detail(String name) async =>
      Map<String, dynamic>.from(current);
  @override
  Future<List<Map<String, dynamic>>> options() async => requestOptionFixtures();
  @override
  Future<List<RequestComment>> comments(String name) async => const [];
  @override
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
      String name,
      {bool thumbnail = false}) async {
    final data = requestData('get_attachment') as Map;
    return (
      filename: '${data['filename']}',
      contentType: '${data['content_type']}',
      bytes: base64Decode('${data['content_base64']}')
    );
  }
}

class _Tasks extends Fake implements WorkflowTaskRepository {
  @override
  Future<WorkflowInstanceDetail> getInstance(String id) async =>
      WorkflowInstanceDetail(
        summary: WorkflowInstanceSummary(
            id: id, subject: 'مساعده', status: 'Completed'),
        activities: const [],
      );
}

class _Voids extends Fake implements RequestVoidRepository {
  _Voids(this.repo);
  final _Repo repo;
  final calls = <String>[];
  Object? failure;

  @override
  Future<Map<String, dynamic>> voidDocument(String name, String reason) async {
    calls.add('void:$name:$reason');
    if (failure != null) throw failure!;
    repo.current = _request(_execution('voided', 'سند ابطال شد',
        canReissue: true,
        voided: {
          'reason': reason,
          'by_name': 'مدیر منابع انسانی',
          'on': '2026-10-08 10:00:00',
          'reference': 'HR-EA-0001'
        }));
    return repo.current;
  }

  @override
  Future<Map<String, dynamic>> reissue(String name) async {
    calls.add('reissue:$name');
    if (failure != null) throw failure!;
    repo.current = _request(
        _execution('succeeded', 'اجرا انجام شد', canVoid: true));
    return repo.current;
  }
}

Future<(_Repo, _Voids)> _open(WidgetTester tester, Map<String, dynamic> data,
    {double width = 390}) async {
  await tester.binding.setSurfaceSize(Size(width, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _Repo(data);
  final voids = _Voids(repo);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RequestDetailScaffold(
          repository: repo,
          name: '${data['name']}',
          tasks: _Tasks(),
          voidRepository: voids),
    ),
  ));
  await tester.pumpAndSettle();
  return (repo, voids);
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('عملیات'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RequestScreenRegistry.clear);

  test('the model keeps the flags and the void history', () {
    final execution = RequestExecution.fromMap(_execution(
        'voided', 'سند ابطال شد',
        canReissue: true,
        voided: {'reason': _reason, 'by_name': 'مدیر', 'on': '2026-10-08'}));
    expect(execution.voided, isTrue);
    expect(
        (execution.canVoid, execution.canReissue, execution.voidReason),
        (false, true, _reason));
    expect(RequestExecution.fromMap({'state': 'voided'}).sentence,
        'سند ابطال شد');
    expect(RequestExecution.fromMap(null).canVoid, isFalse);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    group('at $width', () {
      testWidgets('a user who cannot void sees neither action', (tester) async {
        await _open(tester,
            _request(_execution('succeeded', 'اجرا انجام شد')), width: width);
        await _menu(tester);
        expect(find.text('ابطال سند'), findsNothing);
        expect(find.text('صدور مجدد'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('void asks for a reason, then the lane shows it and reissue appears',
          (tester) async {
        final (repo, voids) = await _open(tester,
            _request(_execution('succeeded', 'اجرا انجام شد', canVoid: true)),
            width: width);
        await _menu(tester);
        expect(find.text('صدور مجدد'), findsNothing);
        await tester.tap(find.text('ابطال سند'));
        await tester.pumpAndSettle();
        // Empty reason is refused in the dialog; nothing is sent.
        await tester.tap(find.byKey(const ValueKey('void-confirm-button')));
        await tester.pumpAndSettle();
        expect(find.text('دلیل ابطال را بنویسید.'), findsOneWidget);
        expect(voids.calls, isEmpty);
        await tester.enterText(
            find.byKey(const ValueKey('void-reason-field')), _reason);
        await tester.tap(find.byKey(const ValueKey('void-confirm-button')));
        await tester.pumpAndSettle();
        expect(voids.calls, ['void:${repo.current['name']}:$_reason']);
        expect(find.text('سند ابطال شد'), findsWidgets);
        expect(find.textContaining(_reason), findsOneWidget);
        await _menu(tester);
        expect(find.text('ابطال سند'), findsNothing);
        expect(find.text('صدور مجدد'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('reissue is confirmed first and refreshes the lane',
          (tester) async {
        final (repo, voids) = await _open(
            tester,
            _request(_execution('voided', 'سند ابطال شد',
                canReissue: true, voided: {'reason': _reason})),
            width: width);
        await _menu(tester);
        await tester.tap(find.text('صدور مجدد'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('انصراف'));
        await tester.pumpAndSettle();
        expect(voids.calls, isEmpty);
        await _menu(tester);
        await tester.tap(find.text('صدور مجدد'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reissue-confirm-button')));
        await tester.pumpAndSettle();
        expect(voids.calls, ['reissue:${repo.current['name']}']);
        expect(find.text('اجرا انجام شد'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('failures show a Persian sentence per kind', (tester) async {
        final (_, voids) = await _open(tester,
            _request(_execution('succeeded', 'اجرا انجام شد', canVoid: true)),
            width: width);
        final cases = <ApiException, String>{
          const ApiException(
                  kind: ApiFailureKind.validation,
                  message: 'ابطال سند انجام نشد؛ اسناد وابسته به آن را بررسی کنید.',
                  statusCode: 417):
              'ابطال سند انجام نشد؛ اسناد وابسته به آن را بررسی کنید.',
          const ApiException(
                  kind: ApiFailureKind.forbidden, message: 'x', statusCode: 403):
              forbiddenFailureMessage,
          const ApiException(kind: ApiFailureKind.network, message: 'x'):
              'ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.',
        };
        for (final entry in cases.entries) {
          voids.failure = entry.key;
          await _menu(tester);
          await tester.tap(find.text('ابطال سند'));
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('void-reason-field')), _reason);
          await tester.tap(find.byKey(const ValueKey('void-confirm-button')));
          await tester.pumpAndSettle();
          expect(find.text(entry.value), findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
