import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_wait_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_wait_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements WorkflowWaitRepository {}

const options = <String, dynamic>{'wait_version': 1, 'execution_ready': true,
  'time_zone': 'Asia/Tehran', 'zone_source': 'System', 'output_valid': true, 'output_label': 'ادامه',
  'blocked_message': null, 'fields': [
    {'source_kind': 'Original', 'source_stage': '', 'source_field': 'starts', 'field_type': 'Date', 'label': 'تاریخ آغاز'},
    {'source_kind': 'Original', 'source_stage': '', 'source_field': 'scheduled_at', 'field_type': 'DateTime', 'label': 'زمان برنامه'},
  ]};

void main() {
  setUpAll(() async {
    await (FontLoader('Vazirmatn')..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  late _Repository repository;
  setUp(() {
    repository = _Repository();
    when(() => repository.draft('wf', 'wait')).thenAnswer((_) async => null);
    when(() => repository.options('wf', 'wait')).thenAnswer((_) async => options);
    when(() => repository.saveDraft('wf', 'wait', any())).thenAnswer((_) async {});
    when(() => repository.save('wf', 'wait', any())).thenAnswer((_) async {});
    when(() => repository.clearDraft('wf', 'wait')).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester, String type, {double width = 390, Map<String, dynamic> extra = const {}, Future<void> Function()? saved}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = {'wait_version': 1, 'wait_type': type, 'wait_value': type == 'Date' ?
      '${DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first}T09:00' : 24,
      'wait_unit': 'Hour', 'past_policy': 'Continue',
      if (type == 'FormDate') ...{'date_source': {'source_kind': 'Original', 'source_stage': '', 'source_field': 'starts', 'field_type': 'Date'},
        'clock': '09:00', 'offset_direction': 'Before', 'offset_days': 1, 'date_change_policy': 'Keep'}, ...extra};
    final stage = WorkflowStage(id: 'wait', key: 'wait', type: WorkflowStageType.wait, title: 'انتظار پیش از ادامهٔ فرایند',
        sequence: 1, configurationComplete: true, config: config);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('wait-capture'), child: MaterialApp(
      debugShowCheckedModeBanner: false, theme: AsoudTheme.light,
      home: WorkflowWaitSettingsPage(definition: 'wf', stage: stage, repository: repository, onSaved: saved ?? () async {}))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    for (final type in ['Duration', 'Date', 'FormDate']) {
      testWidgets('$type wait uses conditional fields and saves real config at $width', (tester) async {
        var saved = 0;
        await open(tester, type, width: width, saved: () async { saved++; });
        expect(find.text('انتظار و زمان‌بندی'), findsOneWidget);
        expect(find.text('ادامه خودکار'), findsOneWidget);
        expect(find.text('مرحله مقصد'), findsNothing);
        expect(find.text('مدت انتظار *'), type == 'Duration' ? findsOneWidget : findsNothing);
        expect(find.text('تاریخ ادامه فرایند *'), type == 'Date' ? findsOneWidget : findsNothing);
        expect(find.text('فیلد تاریخ *'), type == 'FormDate' ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_WAIT') && width == 390 && type == 'Duration') {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('wait-capture')));
            final picture = await boundary.toImage(pixelRatio: 2);
            final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
            await File('build/wait-settings-390.png').writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tap(tester, 'اعتبارسنجی و ذخیره');
        expect(saved, 1);
        final sent = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
        expect(sent['wait_type'], type);
        if (type != 'Duration') expect(sent.containsKey('wait_unit'), isFalse);
        if (type != 'FormDate') expect(sent.containsKey('date_source'), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('zero duration reports near its field and does not save', (tester) async {
    await open(tester, 'Duration', extra: const {'wait_value': 0});
    await tap(tester, 'اعتبارسنجی و ذخیره');
    expect(find.textContaining('عدد صحیح'), findsOneWidget);
    verifyNever(() => repository.save('wf', 'wait', any()));
  });

  testWidgets('draft needs no real scheduling and preserves invalid editable input', (tester) async {
    await open(tester, 'Duration', extra: const {'wait_value': 'invalid'});
    await tap(tester, 'ذخیره پیش‌نویس');
    final sent = verify(() => repository.saveDraft('wf', 'wait', captureAny())).captured.single as Map;
    expect(sent['wait_value'], 'invalid');
    verifyNever(() => repository.save('wf', 'wait', any()));
  });

  testWidgets('DateTime source uses its own clock and does not send a second clock', (tester) async {
    await open(tester, 'FormDate', extra: const {'date_source': {'source_kind': 'Original', 'source_stage': '',
      'source_field': 'scheduled_at', 'field_type': 'DateTime'}});
    expect(find.text('ساعت ادامه فرایند *'), findsNothing);
    await tap(tester, 'اعتبارسنجی و ذخیره');
    final sent = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
    expect(sent.containsKey('clock'), isFalse);
  });

  testWidgets('matching local draft restores but stale draft cannot overwrite server config', (tester) async {
    await open(tester, 'Duration');
    await tap(tester, 'ذخیره پیش‌نویس');
    final saved = Map<String, dynamic>.from(verify(() => repository.saveDraft('wf', 'wait', captureAny())).captured.single as Map);
    when(() => repository.draft('wf', 'wait')).thenAnswer((_) async => {...saved, 'wait_value': '77'});
    await tester.pumpWidget(const SizedBox());
    await open(tester, 'Duration');
    await tap(tester, 'اعتبارسنجی و ذخیره');
    final restored = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
    expect(restored['wait_value'], '77');
    await tester.pumpWidget(const SizedBox());
    await open(tester, 'Duration', extra: const {'wait_value': 48});
    expect(find.textContaining('نسخهٔ دیگری'), findsOneWidget);
    await tap(tester, 'اعتبارسنجی و ذخیره');
    final current = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
    expect(current['wait_value'], '48');
  });

  testWidgets('changed source metadata blocks save rather than silently changing the binding', (tester) async {
    await open(tester, 'FormDate', extra: const {'date_source': {'source_kind': 'Original', 'source_stage': '',
      'source_field': 'starts', 'field_type': 'DateTime'}});
    await tap(tester, 'اعتبارسنجی و ذخیره');
    expect(find.text('نوع فیلد تغییر کرده است؛ دوباره انتخاب کنید.'), findsOneWidget);
    verifyNever(() => repository.save('wf', 'wait', any()));
  });

  testWidgets('missing server configuration explains disabled save and keeps local draft', (tester) async {
    when(() => repository.options('wf', 'wait')).thenAnswer((_) async => {...options,
      'execution_ready': false, 'blocked_message': 'به‌روزرسانی پایگاه داده لازم است.'});
    await open(tester, 'Duration');
    expect(find.text('به‌روزرسانی پایگاه داده لازم است.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'اعتبارسنجی و ذخیره'));
    expect(button.onPressed, isNull);
    await tap(tester, 'ذخیره پیش‌نویس');
    verify(() => repository.saveDraft('wf', 'wait', any())).called(1);
  });

  testWidgets('server failure preserves inputs and never calls saved callback', (tester) async {
    when(() => repository.save('wf', 'wait', any())).thenThrow(StateError('not acknowledged'));
    var saved = false;
    await open(tester, 'Duration', saved: () async { saved = true; });
    await tap(tester, 'اعتبارسنجی و ذخیره');
    expect(saved, isFalse);
    expect(find.textContaining('اطلاعات فرم حفظ شده'), findsOneWidget);
    expect(find.text('انتظار پیش از ادامهٔ فرایند'), findsOneWidget);
  });

  testWidgets('switching date mode to duration removes old date fields from the save', (tester) async {
    await open(tester, 'Date');
    await tap(tester, 'انتظار تا تاریخ و ساعت مشخص');
    await tester.tap(find.text('انتظار به مدت مشخص').last);
    await tester.pumpAndSettle();
    expect(find.text('تاریخ ادامه فرایند *'), findsNothing);
    expect(find.text('ساعت ادامه فرایند *'), findsNothing);
    await tap(tester, 'اعتبارسنجی و ذخیره');
    final sent = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
    expect(sent['wait_type'], 'Duration');
    expect(sent['wait_value'], '24');
    expect(sent.containsKey('clock'), isFalse);
    expect(sent.containsKey('date_source'), isFalse);
  });

  testWidgets('same date hides offset and supplementary choices remain editable inline', (tester) async {
    await open(tester, 'FormDate');
    await tap(tester, 'چند روز قبل');
    await tester.tap(find.text('همان تاریخ').last);
    await tester.pumpAndSettle();
    expect(find.text('تعداد روز *'), findsNothing);
    await tap(tester, 'تنظیمات تکمیلی');
    expect(find.text('اگر تاریخ فرم تغییر کند'), findsOneWidget);
    expect(find.text('منطقه زمانی: Asia/Tehran (تنظیم سامانه؛ دفتر تنظیم اختصاصی ندارد)'), findsOneWidget);
    await tap(tester, 'اعتبارسنجی و ذخیره');
    final sent = verify(() => repository.save('wf', 'wait', captureAny())).captured.single as Map;
    expect(sent['offset_days'], 0);
  });
}
