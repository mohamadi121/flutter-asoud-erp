import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_start_settings.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_start_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workflow_start_settings_test.dart' as fixtures;

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_WORKFLOW_START')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-start')));
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File('build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('Vazirmatn')
          ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'existing three sections survive and manual mode hides only source selection at $width RTL',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
          value: fixtures.Repository(),
          child: RepaintBoundary(
              key: const ValueKey('capture-start'),
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AsoudTheme.light,
                  home: const WorkflowFormPage()))));
      await tester.pumpAndSettle();
      expect(find.text('مشخصات گردش کار'), findsOneWidget);
      final scroll = find
          .descendant(
              of: find.byKey(const ValueKey('workflow-form-list')),
              matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.text('تنظیمات ظاهری'), 150,
          scrollable: scroll);
      await tester.scrollUntilVisible(find.text('روش ایجاد گردش کار'), 150,
          scrollable: scroll);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('workflow-start-manual')), 150,
          scrollable: scroll);
      expect(
          find.byKey(const ValueKey('workflow-select-source')), findsOneWidget);
      await capture(tester, 'workflow-start-form-${width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('workflow-start-manual')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('workflow-select-source')), findsNothing);
      expect(find.text('نقش‌های مجاز شروع دستی'), findsOneWidget);
      await tester.ensureVisible(
          find.byKey(const ValueKey('workflow-start-additional')));
      await tester.tap(find.byKey(const ValueKey('workflow-start-additional')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowStartAdditionalSheet), findsOneWidget);
      await capture(tester, 'workflow-start-additional-${width.toInt()}');
      await tester.scrollUntilVisible(find.text('۴. ثبت سوابق آغاز گردش کار'), 160,
        scrollable: find.descendant(of: find.byType(WorkflowStartAdditionalSheet), matching: find.byType(Scrollable)).first);
      await capture(tester, 'workflow-start-additional-bottom-${width.toInt()}');
      await tester.tap(find.text('تأیید تنظیمات اضافی'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowStartAdditionalSheet), findsNothing);
      expect(find.text('نقش‌های مجاز شروع دستی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('switching modes cannot send a stale form as a manual trigger', () {
    const source =
        WorkflowStartSettings(source: {'form': 'form', 'revision': 'revision'});
    expect(source.copyWith(manual: true).toMap()['submission_source'], isNull);
    expect(
        source
            .copyWith(manual: true)
            .copyWith(manual: false)
            .toMap()['submission_source'],
        {'form': 'form', 'revision': 'revision'});
  });
}
