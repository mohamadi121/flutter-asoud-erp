import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/data/demo_transfer_service.dart';
import 'package:asoud_erp/features/auth/presentation/pages/demo_transfer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';

const _requestId =
    'generic-request:["srv","offline-preview","c"]:request-local-2';

Widget _app(DemoTransferPage page) => MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: page),
    );

Future<void> seedPreview(FakeLocalRecordStore store) async {
  await store.save(
    id: _requestId,
    entityType: 'generic_request_outbox',
    status: LocalSyncStatus.localOnly,
    payload: {
      'scope': '["srv","offline-preview","c"]',
      'data': {
        'company': 'دفتر نمونه',
        'subject': 'خرید لپ‌تاپ',
        'workflow_definition': 'PREVIEW-REQUEST-PURCHASE',
      },
    },
  );
  SharedPreferences.setMockInitialValues({
    'asoud_workflow_designs_v2':
        '[{"workflow":{"id":"PREVIEW-DRAFT-2","title":"درخواست مرخصی","target_doctype":"ASOUD Workflow Request"},"stages":[],"transitions":[]},'
            '{"workflow":{"id":"PREVIEW-WF-001","title":"فرایند خرید کالا"},"stages":[],"transitions":[]}]',
    'asoud_document_templates_local_v1':
        '[{"name":"LOCAL-TPL-2","title":"سند هزینه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active","company":"دفتر نمونه"},'
            '{"name":"PRESET-ROW","is_sample":true,"title":"نمونه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active"}]',
  });
}

void main() {
  testWidgets('transfer page lists user items, never seeds', (tester) async {
    final store = FakeLocalRecordStore();
    await seedPreview(store);
    var done = false;
    await tester.pumpWidget(_app(DemoTransferPage(
      service: DemoTransferService(store: store),
      submitRequest: (_) async {},
      submitTemplate: (_) async {},
      onDone: () => done = true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('انتقال داده‌های نسخه نمایشی'), findsOneWidget);
    expect(find.text('خرید لپ‌تاپ'), findsOneWidget);
    expect(find.text('درخواست مرخصی'), findsOneWidget);
    expect(find.text('سند هزینه'), findsOneWidget);
    // Seeds are never offered.
    expect(find.text('فرایند خرید کالا'), findsNothing);
    expect(find.text('نمونه'), findsNothing);
    // Workflow designs reference local ids: not transferable.
    expect(find.textContaining('قابل انتقال نیست'), findsOneWidget);
    expect(find.textContaining('شناسه مرحله'), findsOneWidget);
    expect(done, isFalse);
  });

  testWidgets('transfer submits exactly once and removes the local copy',
      (tester) async {
    final store = FakeLocalRecordStore();
    await seedPreview(store);
    var calls = 0;
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(_app(DemoTransferPage(
      service: DemoTransferService(store: store),
      submitRequest: (data) async {
        calls++;
        submitted = data;
      },
      submitTemplate: (_) async {},
      onDone: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('انتقال به سرور').first);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(submitted!['subject'], 'خرید لپ‌تاپ');
    expect(await store.get(_requestId), isNull);
    expect(find.text('خرید لپ‌تاپ'), findsNothing);
    // The other user items are still listed.
    expect(find.text('سند هزینه'), findsOneWidget);
  });

  testWidgets('ignoring discards without submitting; finish closes the page',
      (tester) async {
    final store = FakeLocalRecordStore();
    await seedPreview(store);
    var submits = 0;
    var done = false;
    await tester.pumpWidget(_app(DemoTransferPage(
      service: DemoTransferService(store: store),
      submitRequest: (_) async {
        submits++;
      },
      submitTemplate: (_) async {
        submits++;
      },
      onDone: () => done = true,
    )));
    await tester.pumpAndSettle();

    for (var i = 0; i < 8 && find.text('اتمام').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    // The template card sits just above the finish button: ignoring it
    // discards the copy without any server submit.
    await tester.tap(find.text('نادیده گرفتن').last);
    await tester.pumpAndSettle();
    expect(submits, 0);
    expect(find.text('سند هزینه'), findsNothing);

    await tester.tap(find.text('اتمام'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(await DemoTransferService.isTransferSeen(), isTrue);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('transfer page renders without overflow at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = FakeLocalRecordStore();
      await seedPreview(store);
      await tester.pumpWidget(_app(DemoTransferPage(
        service: DemoTransferService(store: store),
        submitRequest: (_) async {},
        submitTemplate: (_) async {},
        onDone: () {},
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('انتقال داده‌های نسخه نمایشی'), findsOneWidget);
    });
  }
}
