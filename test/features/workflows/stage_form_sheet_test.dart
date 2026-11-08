import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_preview_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {}

FormMap _schema(String title) => {
      'schema_version': 2,
      'kind': 'Stage',
      'title': title,
      'module': '',
      'sections': <FormMap>[
        {
          'id': 's1',
          'title': 'بخش',
          'fields': <FormMap>[
            {'key': 'note', 'label': 'یادداشت', 'type': 'Text'},
          ],
        },
      ],
      'rules': <FormMap>[],
    };

class _Forms extends FormRepository {
  _Forms({this.failFirst = false, this.rows}) : super(_Client(), 'شرکت آزمون');
  final bool failFirst;
  final List<FormMap>? rows;
  final calls = <String>[];
  int attempts = 0;

  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async {
    calls.add(method);
    if (failFirst && attempts++ == 0) {
      throw const ApiException(
          kind: ApiFailureKind.network, message: 'خطای آزمایشی شبکه');
    }
    if (method == 'list_forms') {
      expect(data['company'], 'شرکت آزمون');
      expect(data['kind'], 'Stage');
      return rows ?? _defaults;
    }
    if (method == 'get_form') {
      return {
        'name': data['name'],
        'revision': 'rev-1',
        'schema': _schema('فرم مالی'),
      };
    }
    throw StateError('method $method');
  }
}

final _defaults = <FormMap>[
  {
    'name': 'chk-1',
    'title': 'چک‌لیست بررسی درخواست',
    'description': 'کنترل اطلاعات و مدارک',
    'color': '#2E9E5B',
    'builtin_key': 'stage_request_checklist',
    'builtin_pending': true,
    'schema': _schema('چک‌لیست بررسی درخواست'),
  },
  {
    'name': 'fin-1',
    'title': 'فرم بررسی مالی',
    'description': 'کنترل هزینه و اعتبار',
    'color': '#C99A2E',
    'builtin_key': 'stage_finance_review',
    'builtin_pending': true,
    'schema': _schema('فرم بررسی مالی'),
  },
  {
    'name': 'hr-1',
    'title': 'فرم بررسی منابع انسانی',
    'description': 'بررسی شرایط پرسنلی',
    'color': '#2F80ED',
    'builtin_key': 'stage_hr_review',
    'builtin_pending': true,
    'schema': _schema('فرم بررسی منابع انسانی'),
  },
  {
    'name': 'ops-1',
    'title': 'فرم بررسی عملیاتی / تولید',
    'description': 'بررسی اثر بر برنامه کاری',
    'color': '#1FA2A6',
    'builtin_key': 'stage_operations_review',
    'builtin_pending': true,
    'schema': _schema('فرم بررسی عملیاتی / تولید'),
  },
  {
    'name': 'exp-1',
    'title': 'فرم ثبت نظر کارشناسی',
    'description': 'ثبت نتیجه بررسی تخصصی',
    'color': '#8E5BD0',
    'builtin_key': 'stage_expert_opinion',
    'builtin_pending': true,
    'schema': _schema('فرم ثبت نظر کارشناسی'),
  },
  {
    'name': 'pub-1',
    'title': 'فرم مالی',
    'description': 'فرم منتشرشده شرکت',
    'color': '#C99A2E',
    'status': 'Published',
  },
];

Widget _host(_Forms repository,
        {String? selectedName, ValueChanged<StageFormChoice?>? onResult}) =>
    MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () async {
                        final result = await showStageFormSheet(context,
                            repository: repository,
                            company: 'شرکت آزمون',
                            selectedName: selectedName);
                        onResult?.call(result);
                      },
                      child: const Text('باز کردن'))))),
    );

void main() {
  testWidgets('close button returns null and closes the sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StageFormChoice? result;
    await tester
        .pumpWidget(_host(_Forms(), onResult: (value) => result = value));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب فرم'), findsOneWidget);
    await tester.tap(find.byTooltip('بستن'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('انتخاب فرم'), findsNothing);
  });

  testWidgets(
      'shows the five defaults in contract order with titles and descriptions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_Forms()));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    final titles = find.descendant(of: list, matching: find.byType(Text));
    final shown = <String>[];
    for (final element in titles.evaluate()) {
      final text = (element.widget as Text).data ?? '';
      if (_defaults.any((row) => row['title'] == text)) shown.add(text);
    }
    expect(shown, [
      'چک‌لیست بررسی درخواست',
      'فرم ثبت نظر کارشناسی',
      'فرم بررسی منابع انسانی',
      'فرم بررسی مالی',
      'فرم بررسی عملیاتی / تولید',
      'فرم مالی',
    ]);
    expect(find.text('کنترل اطلاعات و مدارک'), findsOneWidget);
    expect(find.text('ثبت نتیجه بررسی تخصصی'), findsOneWidget);
    expect(find.text('بررسی شرایط پرسنلی'), findsOneWidget);
    expect(find.text('کنترل هزینه و اعتبار'), findsOneWidget);
    expect(find.text('بررسی اثر بر برنامه کاری'), findsOneWidget);
    expect(find.text('فرم دیگری در این گردش کار یافت نشد.'), findsNothing);
    expect(find.text('قالب‌های آماده'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters by title and description with ي/ك normalization',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_Forms()));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    // ي (0x64a) must match the ی (0x6cc) in «مالی».
    await tester.enterText(find.byType(TextField), 'مالي');
    await tester.pump();
    expect(find.text('فرم بررسی مالی'), findsOneWidget);
    expect(find.text('فرم مالی'), findsOneWidget);
    expect(find.text('چک‌لیست بررسی درخواست'), findsNothing);
    // ك (0x643) must match the ک (0x6a9) in «کارشناسی».
    await tester.enterText(find.byType(TextField), 'كارشناسی');
    await tester.pump();
    expect(find.text('فرم ثبت نظر کارشناسی'), findsOneWidget);
    expect(find.text('فرم بررسی مالی'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('نتیجه‌ای پیدا نشد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ساخت فرم اختصاصی returns StageFormCreate', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StageFormChoice? result;
    await tester
        .pumpWidget(_host(_Forms(), onResult: (value) => result = value));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ساخت فرم اختصاصی'));
    await tester.pumpAndSettle();
    expect(result, isA<StageFormCreate>());
    expect(find.text('انتخاب فرم'), findsNothing);
  });

  testWidgets(
      'tapping a card returns StageFormPicked with name, builtinKey and title',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StageFormChoice? result;
    await tester
        .pumpWidget(_host(_Forms(), onResult: (value) => result = value));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فرم مالی'));
    await tester.pumpAndSettle();
    final picked = result as StageFormPicked;
    expect(picked.name, 'pub-1');
    expect(picked.builtinKey, isNull);
    expect(picked.title, 'فرم مالی');
    expect(find.text('انتخاب فرم'), findsNothing);
  });

  testWidgets(
      'preview of a pending default uses its schema and makes no get_form call',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Forms();
    await tester.pumpWidget(_host(repository));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-form-preview-chk-1')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['list_forms']);
    expect(find.byType(FormPreviewPage), findsOneWidget);
    final preview =
        tester.widget<FormPreviewPage>(find.byType(FormPreviewPage));
    expect(preview.schema['title'], 'چک‌لیست بررسی درخواست');
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview of a published form calls get_form', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Forms();
    await tester.pumpWidget(_host(repository));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-form-preview-pub-1')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['list_forms', 'get_form']);
    expect(find.byType(FormPreviewPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forbidden texts never appear', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_Forms()));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('قالب‌های آماده'), findsNothing);
    expect(find.text('فرم دیگری در این گردش کار یافت نشد.'), findsNothing);
    expect(find.textContaining('Frappe'), findsNothing);
    expect(find.textContaining('ERPNext'), findsNothing);
    expect(find.textContaining('DocType'), findsNothing);
    expect(find.textContaining('PREVIEW-'), findsNothing);
    expect(find.textContaining('SYS-'), findsNothing);
    expect(find.textContaining('WF-'), findsNothing);
    expect(find.textContaining('LOCAL-'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error shows the Persian message and retry reloads',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_Forms(failFirst: true)));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('خطای آزمایشی شبکه'), findsOneWidget);
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 60-character title does not overflow at 320 px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longTitle = 'ف' * 60;
    final rows = [
      for (final row in _defaults)
        if (row['name'] == 'pub-1') {...row, 'title': longTitle} else row,
    ];
    await tester.pumpWidget(_host(_Forms(rows: rows)));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text(longTitle), findsOneWidget);
    expect(find.byType(OverflowBox), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
