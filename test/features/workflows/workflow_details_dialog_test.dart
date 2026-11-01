import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Map<String, dynamic> _saved(String status, {bool pending = false, bool stale = false,
    bool routesComplete = true, bool summary = true}) => {
  'workflow': {
    'name': 'definition', 'workflow_code': 'WF-1405-062', 'workflow_title': 'بررسی درخواست کارکنان',
    'target_doctype': 'Journal Entry', 'status': status, 'is_locked': pending || stale,
    'version_no': 7, 'steps_count': 99, 'modified': null,
    'missing_requirements': stale ? ['Frappe Workflow', 'Transitions'] : <String>[],
  },
  'stages': [
    {'name': 'start', 'stage_key': 'start', 'stage_type': 'Start', 'stage_title': 'شروع',
      'sequence_no': 0, 'configuration_status': 'Complete', 'config': <String, dynamic>{}},
    {'name': 'task', 'stage_key': 'task', 'stage_type': 'User Task', 'stage_title': 'بررسی',
      'sequence_no': 1, 'configuration_status': pending ? 'Pending' : 'Complete',
      'config': {'submission_source': {'form': 'form', 'revision': 'revision',
        'title': 'درخواست مرخصی کارکنان', 'kind': 'Request'}}},
    {'name': 'end', 'stage_key': 'end', 'stage_type': 'End', 'stage_title': 'پایان',
      'sequence_no': 2, 'configuration_status': 'Complete', 'config': <String, dynamic>{}},
  ],
  'transitions': [
    {'name': 'one', 'from_stage': 'start', 'to_stage': 'task', 'condition': <String, dynamic>{}},
    if (routesComplete)
      {'name': 'two', 'from_stage': 'task', 'to_stage': 'end', 'condition': <String, dynamic>{}},
  ],
  if (summary) 'details_summary': {'steps_count': 2, 'stages_complete': !pending,
    'routes_complete': routesComplete, 'requirements': [
      if (pending) 'تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.',
      if (!routesComplete) 'همهٔ مراحل باید از شروع قابل دسترس و به یک پایان متصل باشند.',
    ]},
};

class _Client extends Mock implements FrappeApiClient {
  _Client(this.saved);
  final Map<String, dynamic> saved;
  int loads = 0;
  bool failFirst = false;
  @override
  Future<dynamic> callAsoudMethod(String method, {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.workflow.get_workflow_design');
    expect(data, {'definition': 'definition'});
    loads++;
    if (failFirst && loads == 1) {
      throw const ApiException(kind: ApiFailureKind.network, message: 'network');
    }
    return saved;
  }
}

Future<void> _open(WidgetTester tester, _Client client, double width) async {
  tester.view.physicalSize = Size(width, 740);
  tester.view.devicePixelRatio = 1;
  final repository = FrappeWorkflowRepository(client);
  await tester.pumpWidget(RepaintBoundary(key: const ValueKey('details-capture'), child: MaterialApp(
    debugShowCheckedModeBanner: false, theme: AsoudTheme.light,
    builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(
      onPressed: () => showDialog<bool>(context: context,
        builder: (_) => WorkflowDetailsDialog(load: () => repository.getDesign('definition'))),
      child: const Text('باز کردن'))))),
  )));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
}

Future<void> _showRequirements(WidgetTester tester) async {
  await tester.ensureVisible(find.text('موارد نیازمند تکمیل'));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String state) async {
  tester.view.physicalSize = const Size(390, 1000);
  await tester.pumpAndSettle();
  final scrollable = find.descendant(of: find.byType(WorkflowDetailsDialog), matching: find.byType(Scrollable));
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('details-capture')));
    final rendered = await boundary.toImage(pixelRatio: 2);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/workflow-details-${state.toLowerCase()}.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    rendered.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final state in ['Active', 'Inactive', 'Pending']) {
      testWidgets('details $state at $width uses saved data and has no mutations', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = state == 'Pending';
        final client = _Client(_saved(pending ? 'Inactive' : state,
            pending: pending, routesComplete: !pending));
        await _open(tester, client, width);
        expect(find.text('جزئیات گردش‌کار'), findsOneWidget);
        expect(find.text('بررسی درخواست کارکنان'), findsOneWidget);
        expect(find.text('WF-1405-062'), findsOneWidget);
        expect(find.text('۷'), findsOneWidget);
        expect(find.text('۲'), findsOneWidget); // real graph, not the stale count 99
        expect(find.text('درخواست مرخصی کارکنان'), findsOneWidget);
        expect(find.text(pending ? 'طراحی مراحل' : 'مشاهده مراحل'), findsOneWidget);
        expect(find.text(pending ? 'نیازمند تکمیل' : state == 'Active' ? 'فعال' : 'غیرفعال'), findsOneWidget);
        if (pending) {
          await _showRequirements(tester);
          expect(find.text('تکمیل تنظیمات مراحل و مسیرهای خروجی'), findsOneWidget);
        } else {
          expect(find.text('موارد نیازمند تکمیل'), findsNothing);
          expect(find.text('تکمیل شده'), findsNWidgets(2));
        }
        if (width == 390 && const bool.fromEnvironment('CAPTURE_WORKFLOW_DETAILS')) {
          await _capture(tester, state);
        }
        for (final text in ['حذف', 'فعال‌سازی', 'غیرفعال‌سازی', 'Frappe', 'ERPNext', 'ASOUD']) {
          expect(find.textContaining(text), findsNothing);
        }
        expect(client.loads, 1);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(OutlinedButton, 'بستن'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkflowDetailsDialog), findsNothing);
      });
    }

    testWidgets('fresh complete graph overrides stale pending list at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, _Client(_saved('Inactive', stale: true)), width);
      expect(find.text('غیرفعال'), findsOneWidget);
      expect(find.text('موارد نیازمند تکمیل'), findsNothing);
      expect(find.text('طراحی مراحل'), findsNothing);
      expect(find.text('مشاهده مراحل'), findsOneWidget);
      expect(find.textContaining('Frappe'), findsNothing);
      expect(find.text('تکمیل شده'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('incomplete configuration does not mislabel complete exits at $width', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, _Client(_saved('Inactive', pending: true)), width);
      expect(find.text('تکمیل شده'), findsOneWidget);
      expect(find.text('تکمیل نشده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('read failure is retryable and never displays invented validation', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Client(_saved('Active'))..failFirst = true;
    await _open(tester, client, 390);
    expect(find.text('مشاهده مراحل'), findsNothing);
    expect(find.text('موارد نیازمند تکمیل'), findsNothing);
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('مشاهده مراحل'), findsOneWidget);
    expect(client.loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older server is unverified, not invented missing routes', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, _Client(_saved('Inactive', summary: false)), 390);
    expect(find.text('بررسی نشده'), findsNWidgets(2));
    expect(find.text('تکمیل نشده'), findsNothing);
    expect(find.text('موارد نیازمند تکمیل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native related document uses Persian label and view action closes details', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = _saved('Active');
    ((saved['stages'] as List)[1] as Map)['config'] = <String, dynamic>{};
    final client = _Client(saved);
    await _open(tester, client, 390);
    expect(find.text('سند حسابداری'), findsOneWidget);
    expect(find.textContaining('Journal Entry'), findsNothing);
    await tester.tap(find.text('مشاهده مراحل'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowDetailsDialog), findsNothing);
    expect(client.loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy active status is not silently relabeled inactive by a design warning', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, _Client(_saved('Active', pending: true)), 390);
    expect(find.text('فعال'), findsOneWidget);
    expect(find.text('مشاهده مراحل'), findsOneWidget);
    expect(find.text('موارد نیازمند تکمیل'), findsOneWidget);
    expect(find.text('نیازمند تکمیل'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
