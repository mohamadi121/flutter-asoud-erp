import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_form_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements WorkflowRepository {
  Map<String, Object?>? submitted;
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: ['دفتر اول'],
        modules: [
          WorkflowModuleOption(key: 'Purchase', doctypes: [
            WorkflowDoctypeOption(name: 'Material Request', available: true),
            WorkflowDoctypeOption(name: 'Purchase Order', available: true),
          ]),
          WorkflowModuleOption(key: 'HR', doctypes: [
            WorkflowDoctypeOption(name: 'Leave Application', available: true),
            WorkflowDoctypeOption(name: 'Job Applicant', available: false),
          ]),
        ],
      );
  @override
  Future<WorkflowDefinition> createDraft(
      {required String title,
      required String moduleKey,
      required String targetDoctype,
      required String creationMode,
      String? description,
      String? company,
      String? iconKey,
      String? colorHex}) async {
    submitted = {
      'module': moduleKey,
      'doctype': targetDoctype,
    };
    return WorkflowDefinition(
        id: 'WF-NEW',
        code: 'WF-NEW',
        title: title,
        targetDoctype: targetDoctype,
        status: WorkflowDefinitionStatus.inactive,
        isLocked: false,
        version: 1,
        stepsCount: 1,
        modified: null);
  }
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('workflow-doctype')));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('target document picker is present and selects a module doctype at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
        value: repository,
        child: MaterialApp(
            theme: AsoudTheme.light,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const WorkflowFormPage()),
      ));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byKey(const ValueKey('workflow-title')))
          .read<WorkflowFormCubit>();

      // The picker exists and shows the default generic request.
      expect(find.byKey(const ValueKey('workflow-doctype')), findsOneWidget);
      expect(cubit.state.targetDoctype, 'ASOUD Workflow Request');

      // Open the sheet: the generic request plus the module's own documents.
      await _openSheet(tester);
      // The sheet is scoped by its unique title so the field's own display
      // value (also «درخواست گردش‌کار») is not counted.
      final sheet = find.ancestor(
          of: find.text('نوع سند گردش کار'), matching: find.byType(ListView));
      expect(find.descendant(of: sheet, matching: find.text('درخواست گردش‌کار')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('درخواست کالا / خرید')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('سفارش خرید')), findsOneWidget);
      await tester.tap(find.descendant(of: sheet, matching: find.text('سفارش خرید')));
      await tester.pumpAndSettle();
      expect(cubit.state.targetDoctype, 'Purchase Order');

      // Switching to a module that does not offer the chosen document resets
      // it to the always-valid generic request.
      cubit.changeModule('HR');
      await tester.pumpAndSettle();
      expect(cubit.state.targetDoctype, 'ASOUD Workflow Request');
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitting a doctype the module does not offer is blocked at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
        value: repository,
        child: MaterialApp(
            theme: AsoudTheme.light,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const WorkflowFormPage()),
      ));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byKey(const ValueKey('workflow-title')))
          .read<WorkflowFormCubit>();

      await tester.enterText(find.byKey(const ValueKey('workflow-title')), 'تأیید خرید');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Force an inconsistent state: module Purchase but a HR-only document.
      cubit.changeModule('Purchase');
      cubit.changeDoctype('Leave Application');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ذخیره و طراحی مراحل'));
      await tester.pumpAndSettle();
      expect(cubit.state.message,
          'نوع سند انتخاب‌شده در این ماژول در دسترس نیست؛ ماژول یا نوع سند را دوباره انتخاب کنید.');
      // The Persian reason is shown on the form, not just in the state.
      final message = find.text(cubit.state.message!);
      if (message.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
            message, 160,
            scrollable: find
                .descendant(of: find.byKey(const ValueKey('workflow-form-list')),
                    matching: find.byType(Scrollable))
                .first);
      }
      expect(message, findsOneWidget);
      expect(repository.submitted, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
