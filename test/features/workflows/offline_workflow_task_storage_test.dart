import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineRemote implements WorkflowTaskRepository {
  Never _fail() => throw const ApiException(
        message: 'offline',
        kind: ApiFailureKind.network,
      );
  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      _fail();
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => _fail();
  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async =>
      _fail();
  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) async =>
      _fail();
  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) async =>
      _fail();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('پیش‌نویس آفلاین بعد از ساخت دوباره repository باقی می‌ماند', () async {
    final first = PreviewWorkflowTaskRepository(_OfflineRemote());
    await first.getMyTasks();
    await first.saveDraft('WFT-OFFLINE-001', {'request_title': 'خرید کاغذ'});

    final second = PreviewWorkflowTaskRepository(_OfflineRemote());
    await second.getMyTasks();
    final detail = await second.getTask('WFT-OFFLINE-001');
    expect(detail.values['request_title'], 'خرید کاغذ');
    expect(detail.task.localOnly, isTrue);
  });

  test('شرط فوری آفلاین به کارتابل تأیید مدیر هدایت می‌شود', () async {
    final repository = PreviewWorkflowTaskRepository(_OfflineRemote());
    await repository.getMyTasks();
    await repository.completeTask(
      task: 'WFT-OFFLINE-001',
      action: 'Complete',
      response: const {
        'request_title': 'خرید کاغذ',
        'priority': 'فوری',
        'confirmed': true,
      },
    );
    final tasks = await repository.getMyTasks();
    expect(tasks.single.id, 'WFT-OFFLINE-URGENT');
    final detail = await repository.getTask(tasks.single.id);
    expect(detail.stageType, 'Approval');
    expect(detail.previousData.single.values.first.value, 'خرید کاغذ');
    expect(detail.activities.last.action, 'Condition True');
    await repository.completeTask(
      task: tasks.single.id,
      action: 'Approve',
    );
    expect(await repository.getMyTasks(), isEmpty);
  });

  test(
      'بازگشت آفلاین علت را نگه می‌دارد و فرم اصلاح را با داده قبلی باز می‌کند',
      () async {
    final repository = PreviewWorkflowTaskRepository(_OfflineRemote());
    await repository.getMyTasks();
    await repository.completeTask(
      task: 'WFT-OFFLINE-001',
      action: 'Complete',
      response: const {
        'request_title': 'خرید کاغذ',
        'priority': 'فوری',
        'confirmed': true,
      },
    );
    final approval = (await repository.getMyTasks()).single;
    await repository.completeTask(
      task: approval.id,
      action: 'Return',
      comment: 'مبلغ اصلاح شود',
    );

    final correction = (await repository.getMyTasks()).single;
    expect(correction.id, 'WFT-OFFLINE-CORRECTION');
    final detail = await repository.getTask(correction.id);
    expect(detail.values['request_title'], 'خرید کاغذ');
    expect(detail.activities.last.comment, 'مبلغ اصلاح شود');
    expect(detail.allowReturn, isFalse);
  });

  test('شرط عادی آفلاین به کارتابل بررسی عادی هدایت می‌شود', () async {
    final repository = PreviewWorkflowTaskRepository(_OfflineRemote());
    await repository.getMyTasks();
    await repository.completeTask(
      task: 'WFT-OFFLINE-001',
      action: 'Complete',
      response: const {'priority': 'عادی', 'confirmed': true},
    );
    final tasks = await repository.getMyTasks();
    expect(tasks.single.id, 'WFT-OFFLINE-NORMAL');
    final detail = await repository.getTask(tasks.single.id);
    expect(detail.activities.last.action, 'Condition False');
  });
}
