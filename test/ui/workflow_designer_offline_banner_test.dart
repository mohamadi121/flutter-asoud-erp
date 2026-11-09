import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository that reports itself as an offline preview and serves a local
/// design, so the designer banner must say the draft is on the device, not the
/// server.
class _OfflineRepository implements WorkflowRepository, OfflinePreviewAware {
  @override
  bool get isOfflinePreview => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<WorkflowDesign> getDesign(String definition) async =>
      WorkflowDesign(
        workflow: const WorkflowDefinition(
          id: 'PREVIEW-DRAFT-1',
          code: 'PREVIEW-1',
          title: 'مرخصی تست',
          targetDoctype: 'Leave Application',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: 1,
          modified: null,
          pendingReason: 'ذخیره محلی؛ در انتظار همگام‌سازی با ASOUD ERP',
        ),
        stages: [
          const WorkflowStage(
            id: 'PREVIEW-DRAFT-1-START',
            key: 'START',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 1,
            configurationComplete: false,
          ),
        ],
        transitions: const [],
      );

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: ['دفتر نمونه آفلاین'],
        modules: [
          WorkflowModuleOption(
            key: 'HR',
            doctypes: [
              WorkflowDoctypeOption(name: 'Leave Application', available: true),
            ],
          ),
        ],
      );
}

void main() {
  testWidgets('در پیش‌نمایش آفلاین بنر طراح، ذخیره روی سرور را نمی‌گوید',
      (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<WorkflowRepository>.value(
        value: _OfflineRepository(),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: WorkflowDesignerPage(definition: 'PREVIEW-DRAFT-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طراحی فرایند'), findsOneWidget);
    expect(
      find.text('تغییرات این پیش‌نویس روی دستگاه ذخیره شد؛ همگام‌سازی با سرور تأیید نشده است.'),
      findsOneWidget,
    );
    expect(
      find.text('تغییرات این پیش‌نویس روی سرور ذخیره شده است.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
