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
        companies: ['دفتر اول', 'دفتر دوم'],
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
      'title': title,
      'module': moduleKey,
      'doctype': targetDoctype,
      'mode': creationMode,
      'description': description,
      'company': company,
      'icon': iconKey,
      'color': colorHex
    };
    // Keep the form visible to check that a server failure preserves edits.
    throw StateError('Server unavailable');
  }
}

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('workflow settings persist and submit at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
        value: repository,
        child: MaterialApp(
            theme: AsoudTheme.light, home: const WorkflowFormPage()),
      ));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('workflow-title'));
      final cubit = tester.element(title).read<WorkflowFormCubit>();
      expect(Directionality.of(tester.element(title)), TextDirection.rtl);
      expect(find.text('آیکون گردش کار'), findsNothing);
      await tester.tap(find.text('ذخیره و طراحی مراحل'));
      await tester.pumpAndSettle();
      expect(
          find.text('عنوان فرایند باید حداقل ۳ نویسه باشد.'), findsOneWidget);
      expect(repository.submitted, isNull);
      await tester.enterText(title, 'تأیید خرید');
      await tester.enterText(
          find.byKey(const ValueKey('workflow-description')), 'شرح فرایند');
      await tester.tap(find.byKey(const ValueKey('workflow-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-icon-purchase')));
      await tester.tap(find.byKey(const ValueKey('workflow-color-#16A765')));
      final toggle = find.byType(SwitchListTile);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final company =
          find.widgetWithText(DropdownButtonFormField<String>, 'دفتر / شرکت');
      await tester.ensureVisible(company);
      tester
          .widget<DropdownButtonFormField<String>>(company)
          .onChanged!('دفتر دوم');
      await tester.pumpAndSettle();
      final doctype =
          find.widgetWithText(DropdownButtonFormField<String>, 'نوع سند *');
      tester
          .widget<DropdownButtonFormField<String>>(doctype)
          .onChanged!('Purchase Order');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('بستن تنظیمات'));
      await tester.pumpAndSettle();
      expect(cubit.state.iconKey, 'purchase');
      expect(cubit.state.colorHex, '#16A765');
      expect(cubit.state.creationMode, 'Template');
      await tester.tap(find.byKey(const ValueKey('workflow-more')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.text('سفارش خرید'), findsOneWidget);
      await tester.tap(find.byTooltip('بستن تنظیمات'));
      await tester.pumpAndSettle();
      expect(find.text('ذخیره و طراحی مراحل').hitTestable(), findsOneWidget);
      await tester.tap(find.text('ذخیره و طراحی مراحل'));
      await tester.pumpAndSettle();
      expect(repository.submitted, {
        'title': 'تأیید خرید',
        'description': 'شرح فرایند',
        'module': 'Purchase',
        'doctype': 'Purchase Order',
        'company': 'دفتر دوم',
        'mode': 'Template',
        'icon': 'purchase',
        'color': '#16A765'
      });
      expect(cubit.state.title, 'تأیید خرید');
      tester.view.viewInsets =
          FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final save = find.text('ذخیره و طراحی مراحل');
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(544));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      // A module change must reset the target document in the reopened sheet.
      cubit.changeModule('HR');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-more')));
      await tester.pumpAndSettle();
      expect(find.text('درخواست مرخصی'), findsOneWidget);
      expect(find.text('سفارش خرید'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
