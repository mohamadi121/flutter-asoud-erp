import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_start_settings.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_start_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workflow_start_settings_test.dart' as fixtures;

class _PreviewClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}

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
    testWidgets('source sheet leaves the subtitle and twelve logical pixels visible at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(value: _PreviewClient(),
        child: RepositoryProvider<WorkflowRepository>.value(value: fixtures.Repository(),
          child: MaterialApp(theme: AsoudTheme.light, home: const WorkflowFormPage()))));
      await tester.pumpAndSettle();
      expect(find.text('ماژول *'), findsNothing);
      final headerBottom = tester.getBottomLeft(find.text('اطلاعات پایه فرایند را وارد کنید')).dy;
      final scroll = find.descendant(of: find.byKey(const ValueKey('workflow-form-list')),
          matching: find.byType(Scrollable)).first;
      final source = find.byKey(const ValueKey('workflow-select-source'));
      await tester.scrollUntilVisible(source, 150, scrollable: scroll);
      await tester.ensureVisible(source);
      await tester.pumpAndSettle();
      await tester.tap(source.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(headerBottom + 12, 1));
      expect(tester.takeException(), isNull);
    });

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
      final manual = find.byKey(const ValueKey('workflow-start-manual'));
      await tester.ensureVisible(manual);
      await tester.pumpAndSettle();
      expect(manual.hitTestable(), findsOneWidget);
      await tester.tap(manual.hitTestable());
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('workflow-select-source')), findsNothing);
      expect(find.text('نقش‌های مجاز شروع دستی'), findsOneWidget);
      await tester.ensureVisible(
          find.text('تنظیمات اضافی (اختیاری)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تنظیمات اضافی (اختیاری)'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowStartAdditionalFields), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await capture(tester, 'workflow-start-additional-${width.toInt()}');
      await tester.scrollUntilVisible(find.text('۴. ثبت سوابق آغاز گردش کار'), 160,
        scrollable: scroll);
      await capture(tester, 'workflow-start-additional-bottom-${width.toInt()}');
      await tester.scrollUntilVisible(find.text('تأیید تنظیمات اضافی'), 120, scrollable: scroll);
      await tester.ensureVisible(find.text('تأیید تنظیمات اضافی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأیید تنظیمات اضافی').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowStartAdditionalFields), findsNothing);
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
