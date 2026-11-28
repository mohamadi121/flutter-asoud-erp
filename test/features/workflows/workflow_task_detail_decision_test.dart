import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  const _Call(this.action, this.comment);
  final String action;
  final String? comment;
}

/// Captures the decision the user submits so the test can prove which button
/// sent which action and whether the typed reason travelled with it.
class _CaptureRepository implements WorkflowTaskRepository {
  _CaptureRepository(this.detail);
  final WorkflowTaskDetail detail;
  final List<_Call> calls = [];

  @override
  bool get isOfflinePreview => false;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      [detail.task];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) async =>
      '';

  @override
  Future<void> completeTask(
      {required String task,
      required String action,
      String? comment,
      Map<String, dynamic> response = const {}}) async {
    calls.add(_Call(action, comment));
  }
}

WorkflowTaskDetail _detail() => const WorkflowTaskDetail(
      task: WorkflowTask(
        id: 'WFT-2026-00042',
        instance: 'WFI-2026-00042',
        stage: 'STAGE-APPROVAL',
        title: 'تأیید درخواست خرید لپ‌تاپ',
        status: 'Open',
      ),
      stageType: 'Approval',
      allowReject: true,
      allowReturn: true,
    );

Widget _app(WorkflowTaskRepository repository) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const WorkflowTaskDetailPage(task: 'WFT-2026-00042')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<_CaptureRepository> _open(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _CaptureRepository(_detail());
  await tester.pumpWidget(_app(repository));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

/// «رد» is an outlined button (a warning, distinct from the filled «تأیید»
/// and «بازگشت»); the other two are filled. The finder returns the concrete
/// button type so the enabled/disabled checks keep working.
Finder _button(String label) =>
    label == 'رد'
        ? find.widgetWithText(OutlinedButton, label)
        : find.widgetWithText(FilledButton, label);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label)).onPressed != null;

void main() {
  testWidgets('سه دکمهٔ تصمیم هم‌رده و دلیل اجباری برای رد/بازگشت',
      (tester) async {
    final repository = await _open(tester, 390);

    expect(_button('تأیید'), findsOneWidget);
    expect(_button('رد'), findsOneWidget);
    expect(_button('بازگشت'), findsOneWidget);
    expect(find.text('برای رد یا بازگشت، نوشتن دلیل الزامی است.'), findsOneWidget);

    // «رد» حاشیه‌دار است تا از «بازگشت» (پررنگ) و «تأیید» (پررنگ) متمایز دیده شود.
    expect(find.widgetWithText(OutlinedButton, 'رد'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'بازگشت'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'تأیید'), findsOneWidget);

    // بدون دلیل، اقدام‌های مخرب مسدودند
    expect(_enabled(tester, 'تأیید'), isTrue);
    expect(_enabled(tester, 'رد'), isFalse);
    expect(_enabled(tester, 'بازگشت'), isFalse);

    await tester.enterText(find.byType(TextField), 'بودجه کافی نیست');
    await tester.pump();
    expect(_enabled(tester, 'رد'), isTrue);
    expect(_enabled(tester, 'بازگشت'), isTrue);

    await tester.tap(_button('رد'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.action, 'Reject');
    expect(repository.calls.single.comment, 'بودجه کافی نیست');
  });

  testWidgets('«رد» غیرفعال رنگ کم‌رنگ‌تری از حالت فعال دارد', (tester) async {
    await _open(tester, 390);
    Color fg(Set<WidgetState> states) => tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'رد'))
        .style!
        .foregroundColor!
        .resolve(states)!;
    final enabled = fg(const {});
    final disabled = fg(const {WidgetState.disabled});
    expect(enabled, AsoudColors.danger);
    expect(disabled, AsoudColors.danger.withValues(alpha: .38));
    expect(disabled, isNot(enabled));
  });

  testWidgets('روی عرض ۳۲۰ دکمه‌ها بدون سرریز روی هم می‌نشینند',
      (tester) async {
    await _open(tester, 320);

    expect(_button('تأیید'), findsOneWidget);
    expect(_button('رد'), findsOneWidget);
    expect(_button('بازگشت'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final approve = tester.getTopLeft(_button('تأیید'));
    final reject = tester.getTopLeft(_button('رد'));
    expect(approve.dy, lessThan(reject.dy));
  });

  testWidgets('تأیید بدون دلیل اقدام را می‌فرستد', (tester) async {
    final repository = await _open(tester, 390);

    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    // A single tap must not approve: the decision bar asks for confirmation.
    expect(find.text('تأیید اقدام'), findsOneWidget);
    expect(repository.calls, isEmpty);

    await tester.tap(find.text('تأیید و ثبت'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.action, 'Approve');
  });

  testWidgets('انصراف از دیالوگ تأیید اقدام را ثبت نمی‌کند', (tester) async {
    final repository = await _open(tester, 390);

    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    expect(find.text('تأیید اقدام'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
    // The decision bar is still there, ready for a real decision.
    expect(_button('تأیید'), findsOneWidget);
  });

  testWidgets('روی عرض ۳۲۰ دیالوگ تأیید بدون سرریز باز می‌شود',
      (tester) async {
    final repository = await _open(tester, 320);

    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    expect(find.text('تأیید اقدام'), findsOneWidget);
    expect(find.text('تأیید و ثبت'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('تأیید و ثبت'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.action, 'Approve');
  });
}
