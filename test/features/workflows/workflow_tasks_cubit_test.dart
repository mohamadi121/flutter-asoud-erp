import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_tasks_cubit.dart';
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
  }) async {
    completed = '$task:$action';
  }
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
}
