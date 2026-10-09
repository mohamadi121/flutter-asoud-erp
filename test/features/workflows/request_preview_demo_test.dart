import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/request_flow_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

class _OfflineTasks extends Fake implements WorkflowTaskRepository {
  static const error =
      ApiException(kind: ApiFailureKind.network, message: 'offline');
  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) =>
      throw error;
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) => throw error;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) =>
      throw error;
  @override
  Future<WorkflowTaskDetail> getTask(String task) => throw error;
  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) =>
      throw error;
  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) =>
      throw error;
  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) =>
      throw error;
}

class _OfflineNotifications extends Fake
    implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowNotification>> getNotifications(
          {bool unreadOnly = false}) =>
      throw const ApiException(
          kind: ApiFailureKind.network, message: 'offline');
  @override
  Future<void> markRead(String notification) => throw const ApiException(
      kind: ApiFailureKind.network, message: 'offline');
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

  test('preview offers the mission and advance demo types with designs',
      () async {
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final types = await repository.options();
    final titles = types.map((row) => row['workflow_title']).toList();
    expect(
      titles,
      containsAll(['درخواست مأموریت', 'درخواست تنخواه']),
    );
    // Leave and purchase are system templates (template_key), not demo types.
    expect(titles, isNot(contains('درخواست مرخصی')));
    expect(titles, isNot(contains('درخواست خرید')));
    expect(types.where((row) => row['name'] == 'DEMO-WF-LEAVE'), isEmpty);
    expect(types.where((row) => row['name'] == 'DEMO-WF-PURCHASE'), isEmpty);
    expect(types.where((row) => row['name'] == 'PREVIEW-REQUEST-PURCHASE'),
        isEmpty);
    for (final type
        in types.where((row) => '${row['name']}'.startsWith('DEMO-'))) {
      expect(type['is_sample'], isTrue);
      expect((type['fields'] as List), isNotEmpty);
    }
    final mission = types.firstWhere((row) => row['name'] == 'DEMO-WF-MISSION');
    expect(
      (mission['fields'] as List).map((field) => (field as Map)['key']),
      containsAll(['destination', 'from_date', 'to_date', 'purpose']),
    );
  });

  test('preview lists four demo requests across the statuses', () async {
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final rows = await repository.list();
    expect(rows, hasLength(4));
    expect(rows.map((row) => row['name']),
        ['DEMO-REQ-003', 'DEMO-REQ-004', 'DEMO-REQ-007', 'DEMO-REQ-008']);
    for (final row in rows) {
      expect(row['is_sample'], isTrue);
    }
    expect(
      rows.map((row) => row['subject']),
      containsAll([
        'مأموریت تهران — نمایشگاه',
        'تنخواه خرداد واحد فروش',
        'مأموریت اصفهان — بازدید مشتری',
        'تنخواه تیر پروژه نمونه',
      ]),
    );
    Map<String, int> counts() {
      final result = <String, int>{};
      for (final row in rows) {
        final label = requestStatus(row).$1;
        result[label] = (result[label] ?? 0) + 1;
      }
      return result;
    }

    expect(
      counts(),
      {
        'در انتظار تأیید': 1,
        'تکمیل شده': 2,
        'رد شده': 1,
      },
    );
    // Dates are relative to now, not frozen samples.
    for (final row in rows) {
      final created = DateTime.parse('${row['creation']}');
      expect(DateTime.now().difference(created).inDays, lessThan(30));
    }
  });

  test('offline leave saved without a typed subject keeps its request title',
      () async {
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());

    await repository.create({
      'template_key': 'leave',
      'values': const {'request_kind': 'Daily'},
      'attachments': const [],
    }, 'request-preview-leave');

    final page = await repository.listPage(templateKey: 'leave');
    expect(page.items.single.subject, 'درخواست مرخصی');
    expect(page.items.single.requestType, 'درخواست مرخصی');
  });

  test('a demo request has values, an attachment and a timeline', () async {
    final tasks = PreviewWorkflowTaskRepository(_OfflineTasks());
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final detail = await repository.detail('DEMO-REQ-003');
    expect(detail['subject'], 'مأموریت تهران — نمایشگاه');
    expect((detail['values'] as Map)['destination'], 'تهران');
    expect((detail['attachments'] as List).single['filename'],
        'دعوت‌نامه نمایشگاه.pdf');
    expect(detail['can_edit'], isFalse);
    expect(detail['can_cancel'], isFalse);

    final instance = await tasks.getInstance('${detail['workflow_instance']}');
    final comments = instance.activities
        .map((activity) => activity.comment)
        .where((comment) => comment.isNotEmpty)
        .toList();
    expect(comments, contains('با مأموریت موافقت شد.'));
    expect(
      instance.activities.map((activity) => activity.actor),
      containsAll(['سارا محمدی', 'احمد رضایی']),
    );
  });

  test('an authenticated session never sees demo requests or types', () async {
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        FrappeUserContext(
            userId: 'demo',
            fullName: 'کاربر نمایشی',
            roles: const ['Employee']));
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => <dynamic>[]);
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    expect(await repository.list(), isEmpty);
    expect(await repository.options(), isEmpty);
  });

  test('preview cartable holds the demo user tasks', () async {
    final repository = PreviewWorkflowTaskRepository(_OfflineTasks());
    final tasks = await repository.getMyTasks();
    expect(tasks.map((task) => task.title), contains('تأیید مرخصی سارا محمدی'));
    expect(
        tasks.map((task) => task.title), contains('بررسی درخواست خرید لپ‌تاپ'));
    for (final task in tasks) {
      expect(task.localOnly, isTrue);
    }
    final detail = await repository.getTask(tasks.first.id);
    expect(detail.activities, isNotEmpty);
    expect(
      detail.previousData
          .expand((section) => section.values)
          .map((value) => value.label),
      contains('عنوان درخواست'),
    );
  });

  test('preview notifications cover the demo flow and support mixed read',
      () async {
    final repository = PreviewWorkflowNotificationRepository(
      _OfflineNotifications(),
    );
    final items = await repository.getNotifications();
    expect(items, hasLength(5));
    expect(
        items.map((item) => item.title), contains('کار جدید به شما ارجاع شد'));
    for (final item in items) {
      expect(item.localOnly, isTrue);
    }
    await repository.markRead(items.first.id);
    expect((await repository.getNotifications()).length, 5);
    expect((await repository.getNotifications(unreadOnly: true)).length, 4);
  });
}
