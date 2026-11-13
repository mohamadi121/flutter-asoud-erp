import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/automatic_action.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/automatic_action_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements WorkflowAutomationRepository {}

const workflow = WorkflowDefinition(id: 'wf', code: 'wf', title: 'فرایند واقعی آزمایش',
    targetDoctype: 'ASOUD Workflow Request', status: WorkflowDefinitionStatus.inactive,
    isLocked: false, version: 1, stepsCount: 3, modified: null);

void main() {
  setUpAll(() async {
    await (FontLoader('Vazirmatn')..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final kind in AutomaticActionType.values) {
      testWidgets('${kind.key} uses only its own fields without overflow at $width', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        final stage = WorkflowStage(id: 'auto', key: 'auto', type: WorkflowStageType.systemAction,
            title: 'اقدام خودکار', sequence: 1, configurationComplete: false,
            config: {'schema_version': 2, 'action_type': kind.key, 'operation': <String, dynamic>{}});
        const end = WorkflowStage(id: 'end', key: 'end', type: WorkflowStageType.end,
            title: 'پایان', sequence: 2, configurationComplete: true);
        when(() => repository.automaticActionDraft('wf', 'auto')).thenAnswer((_) async => null);
        when(() => repository.automaticActionOptions('wf', 'auto')).thenAnswer((_) async => const AutomaticActionOptions(
            fromCache: false, data: {'schema_version': 2, 'execution_ready': false,
              'blocked_message': 'حساب اجرایی دفتر تنظیم نشده است.', 'requests': [], 'documents': [], 'records': [],
              'sources': {'current': [{'key': 'amount', 'label': 'مبلغ', 'type': 'Money'}],
                'writable': [{'key': 'amount', 'label': 'مبلغ', 'type': 'Money'}], 'stages': []},
              'transitions': {}, 'users': [], 'recipient_options': [{'id': 'initiator', 'label': 'درخواست‌کننده'}]}));
        await tester.pumpWidget(RepaintBoundary(key: const ValueKey('auto-capture'), child: MaterialApp(theme: AsoudTheme.light, home: AutomaticActionPage(
            stage: stage, design: WorkflowDesign(workflow: workflow, stages: [stage, end], transitions: const []),
            repository: repository, initialRoutes: const {'Success': 'end'}, onSaved: () async {}))));
        await tester.pumpAndSettle();
        expect(find.textContaining('حساب اجرایی دفتر تنظیم نشده است.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_WORKFLOW_NODES') && width == 390 && kind == AutomaticActionType.calculate) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('auto-capture')));
            final picture = await boundary.toImage(pixelRatio: 2);
            final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
            await File('build/automatic-action-page.png').writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.scrollUntilVisible(find.text('سیاست خطا و تنظیمات فنی'), 220,
            scrollable: find.byType(Scrollable).first);
        await Scrollable.ensureVisible(tester.element(find.text('سیاست خطا و تنظیمات فنی')), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(find.text('سیاست خطا و تنظیمات فنی'));
        await tester.pumpAndSettle();
        expect(find.text('فاصلهٔ اولیه به ثانیه (۳۰ تا ۳۶۰۰)'), findsNothing);
        expect(tester.takeException(), isNull);
        verifyNever(() => repository.saveAutomaticAction(definition: any(named: 'definition'),
            stage: any(named: 'stage'), config: any(named: 'config'), routes: any(named: 'routes')));
      });
    }
  }
}

