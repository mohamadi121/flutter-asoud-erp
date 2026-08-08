import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_tasks_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_task_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements WorkflowTaskRepository {
  var completed = '';
  @override
  bool get isOfflinePreview => true;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      completed.isEmpty
          ? const [
              WorkflowTask(
                id: 'TASK-1',
                instance: 'INSTANCE-1',
                stage: 'STAGE-1',
                title: 'بررسی درخواست',
                status: 'Open',
              ),
            ]
          : const [];

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) async {
    completed = '$task:$action';
  }

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => WorkflowTaskDetail(
        task: (await getMyTasks()).single,
        stageType: 'User Task',
        fields: const [
          WorkflowFormFieldDefinition(
              key: 'title', label: 'عنوان', type: 'Short Text', required: true),
        ],
      );

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  }) async =>
      'local://$filename';
}

void main() {
  test('کارتابل فقط کارهای تخصیص‌یافته را بارگذاری می‌کند', () async {
    final repository = _Repository();
    final cubit = WorkflowTasksCubit(repository);
    await cubit.load();
    expect(cubit.state.tasks.single.id, 'TASK-1');
    expect(cubit.state.offline, isTrue);
    await cubit.close();
  });

  test('تکمیل کار به repository ارسال و کارتابل تازه‌سازی می‌شود', () async {
    final repository = _Repository();
    final cubit = WorkflowTasksCubit(repository);
    await cubit.load();
    await cubit.complete(cubit.state.tasks.single, 'Complete');
    expect(repository.completed, 'TASK-1:Complete');
    expect(cubit.state.tasks, isEmpty);
    await cubit.close();
  });

  test('فرم مرحله بدون فیلد اجباری ارسال نمی‌شود', () async {
    final repository = _Repository();
    final cubit = WorkflowTaskDetailCubit(repository, 'TASK-1');
    await cubit.load();
    expect(await cubit.submit('Complete'), isFalse);
    expect(repository.completed, isEmpty);
    cubit.setValue('title', 'درخواست خرید');
    expect(await cubit.submit('Complete'), isTrue);
    expect(repository.completed, 'TASK-1:Complete');
    await cubit.close();
  });
}
