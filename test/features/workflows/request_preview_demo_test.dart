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

  test('preview offers the four demo request types with designs', () async {
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final types = await repository.options();
    final titles = types.map((row) => row['workflow_title']).toList();
    expect(
      titles,
      containsAll([
        'درخواست مرخصی',
        'درخواست خرید',
        'درخواست مأموریت',
        'درخواست تنخواه',
      ]),
    );
    for (final type
        in types.where((row) => '${row['name']}'.startsWith('DEMO-'))) {
      expect(type['is_sample'], isTrue);
      expect((type['fields'] as List), isNotEmpty);
    }
    final leave = types.firstWhere((row) => row['name'] == 'DEMO-WF-LEAVE');
    expect(
      (leave['fields'] as List).map((field) => (field as Map)['key']),
      containsAll(['leave_type', 'from_date', 'to_date', 'reason']),
    );
  });

  test('preview lists eight demo requests across all statuses', () async {
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final rows = await repository.list();
    expect(rows, hasLength(8));
    for (final row in rows) {
      expect(row['is_sample'], isTrue);
    }
    expect(
      rows.map((row) => row['subject']),
      containsAll([
        'مرخصی استحقاقی تابستان',
        'خرید لپ‌تاپ برای واحد فروش',
        'مأموریت تهران — نمایشگاه',
        'تنخواه خرداد واحد فروش',
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
        'پیش‌نویس': 1,
        'در انتظار تأیید': 2,
        'برگشت برای اصلاح': 1,
        'تکمیل شده': 2,
        'رد شده': 1,
        'لغو شده': 1,
      },
    );
    // Dates are relative to now, not frozen samples.
    for (final row in rows) {
      final created = DateTime.parse('${row['creation']}');
      expect(DateTime.now().difference(created).inDays, lessThan(30));
    }
  });

  test('a demo request has values, an attachment and a timeline', () async {
    final tasks = PreviewWorkflowTaskRepository(_OfflineTasks());
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final detail = await repository.detail('DEMO-REQ-002');
    expect(detail['subject'], 'خرید لپ‌تاپ برای واحد فروش');
    expect((detail['values'] as Map)['category'], 'تجهیزات IT');
    expect(
        (detail['attachments'] as List).single['filename'], 'پیش‌فاکتور.pdf');

    final instance = await tasks.getInstance('${detail['workflow_instance']}');
    final comments = instance.activities
        .map((activity) => activity.comment)
        .where((comment) => comment.isNotEmpty)
        .toList();
    expect(comments, contains('لطفاً پیش‌فاکتور را پیوست کنید.'));
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
