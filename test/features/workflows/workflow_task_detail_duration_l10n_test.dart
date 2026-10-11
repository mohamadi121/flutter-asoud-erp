import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_format.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';

class _FakeRepo implements WorkflowTaskRepository {
  _FakeRepo(this.detail);
  final WorkflowTaskDetail detail;

  @override
  bool get isOfflinePreview => false;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      [detail.task];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances(
          {String? status}) async =>
      const [];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  }) async =>
      '';

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) async {}
}

void main() {
  group('T2: Duration map formatting and task detail localization', () {
    test('formatPersianDuration formats duration maps and strings correctly',
        () {
      final mapDays = {
        'unit': 'day',
        'days': 1.0,
        'hours': null,
        'day_equivalent': 1.0,
      };
      expect(formatPersianDuration(mapDays), '۱ روز');

      final mapHours = {
        'unit': 'hour',
        'hours': 2.0,
        'days': null,
      };
      expect(formatPersianDuration(mapHours), '۲ ساعت');

      expect(formatPersianDuration({'unit': 'day'}), 'روزانه');
      expect(formatPersianDuration({'unit': 'hour'}), 'ساعتی');

      const rawString =
          '{unit: day, days: 1.0, hours: null, day_equivalent: 1.0}';
      expect(formatPersianDuration(rawString), '۱ روز');
    });

    test('priority and frequency maps translate English terms', () {
      expect(persianPriorityLabel('Normal'), 'عادی');
      expect(persianPriorityLabel('High'), 'زیاد');
      expect(persianPriorityLabel('Low'), 'کم');
      expect(persianPriorityLabel('Urgent'), 'فوری');

      expect(persianFrequencyLabel('Daily'), 'روزانه');
      expect(persianFrequencyLabel('Hourly'), 'ساعتی');
    });

    testWidgets(
        'WorkflowTaskDetailPage formats duration map and does not leak raw toString',
        (tester) async {
      final detail = WorkflowTaskDetail(
        task: const WorkflowTask(
          id: 'WFT-2026-00030',
          instance: 'WFI-2026-00029',
          stage: 'STAGE-FILL',
          title: 'تکمیل فرم درخواست',
          status: 'Completed',
        ),
        stageType: 'User Task',
        fields: const [
          WorkflowFormFieldDefinition(
            key: 'leave_duration',
            label: 'مدت مرخصی',
            type: 'Data',
            required: false,
          ),
          WorkflowFormFieldDefinition(
            key: 'request_freq',
            label: 'نوع درخواست',
            type: 'Choice',
            required: true,
            options: ['Daily', 'Hourly'],
          ),
        ],
        values: const {
          'leave_duration': {
            'unit': 'day',
            'days': 1.0,
            'hours': null,
            'day_equivalent': 1.0,
          },
          'request_freq': 'Daily',
        },
        documentValues: const [
          WorkflowTaskDataValue(
            key: 'priority',
            label: 'Priority',
            value: 'Normal',
          ),
        ],
      );

      await tester.pumpWidget(
        RepositoryProvider<WorkflowTaskRepository>.value(
          value: _FakeRepo(detail),
          child: MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: WorkflowTaskDetailPage(task: 'WFT-2026-00030'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find Persian duration "۱ روز" and NOT find raw dictionary string
      expect(find.text('۱ روز'), findsOneWidget);
      expect(find.textContaining('{unit: day'), findsNothing);

      // Should find Persian frequency "روزانه" instead of raw English "Daily"
      expect(find.text('روزانه'), findsOneWidget);
      expect(find.text('Daily'), findsNothing);

      // Technical details section should have Persian "عادی" for Normal priority
      await tester.tap(find.text('جزئیات فنی'));
      await tester.pumpAndSettle();
      expect(find.text('عادی'), findsOneWidget);
      expect(find.text('Normal'), findsNothing);
    });
  });
}
