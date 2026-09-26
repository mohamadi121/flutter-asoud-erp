import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/request_flow_pages.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_print.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements GenericRequestRepository {}

class _Tasks extends Fake implements WorkflowTaskRepository {
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      WorkflowInstanceDetail(
          summary: const WorkflowInstanceSummary(
              id: 'WF-1',
              subject: 'خرید لپ‌تاپ',
              status: 'Running',
              currentStageTitle: 'تأیید مدیر مستقیم'),
          activities: [
            WorkflowTaskActivity(
                actor: 'محمد رضایی',
                action: 'Complete',
                stageTitle: 'ثبت درخواست',
                createdOn: DateTime(2026, 9, 26, 10, 15)),
          ]);
}

const _type = {
  'name': 'purchase',
  'workflow_title': 'درخواست خرید',
  'short_title': 'ثبت درخواست خرید کالا و خدمات',
  'icon_key': 'cart',
  'fields': [
    {
      'key': 'category',
      'label': 'دسته‌بندی',
      'type': 'Choice',
      'required': true,
      'options': ['تجهیزات IT', 'اداری'],
    },
    {'key': 'description', 'label': 'شرح درخواست', 'type': 'Long Text'},
  ],
};

Map<String, dynamic> _request({String status = 'Running'}) => {
      'name': 'PR-1403-025',
      'company': 'شرکت نمونه',
      'workflow_definition': 'purchase',
      'request_type': 'درخواست خرید',
      'subject': 'خرید لپ‌تاپ برای واحد طراحی',
      'department': 'طراحی',
      'requester_name': 'محمد رضایی',
      'creation': '2026-09-26 10:15:00',
      'workflow_instance': 'WF-1',
      'status': status,
      'values': {
        'category': 'تجهیزات IT',
        'items': [
          {
            'item_code': 'LAP',
            'item_name': 'لپ‌تاپ Dell',
            'qty': 2,
            'uom': 'عدد'
          }
        ],
      },
      'attachments': [
        {'name': 'F-1', 'filename': 'پیش فاکتور.pdf'}
      ],
    };

Widget _app(Widget home) => MaterialApp(
    theme: AsoudTheme.light,
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: home);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets('list → type → designed form → success summary', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    when(() => repo.list()).thenAnswer((_) async => []);
    when(() => repo.pending()).thenAnswer((_) async => []);
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    Map<String, dynamic>? sent;
    when(() => repo.create(any(), any())).thenAnswer((call) async {
      sent = Map.from(call.positionalArguments.first as Map);
      return _request();
    });
    await tester.pumpWidget(
        _app(GenericRequestsPage(company: 'شرکت نمونه', repository: repo)));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('درخواست جدید'));
    await _tap(tester, find.text('درخواست خرید'));

    expect(find.text('فرم درخواست خرید'), findsOneWidget);
    expect(find.text('نوع درخواست *'), findsNothing); // chosen beforehand
    expect(find.text('فایل یا فایل‌ها را انتخاب کنید'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان درخواست *'),
        'خرید لپ‌تاپ برای واحد طراحی');
    await _tap(tester, find.text('دسته‌بندی'));
    await tester.tap(find.text('تجهیزات IT').last);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('ثبت درخواست').last);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    expect(sent!['workflow_definition'], 'purchase');
    expect(sent!['values'], {'category': 'تجهیزات IT'});
    expect(find.text('درخواست شما با موفقیت ثبت شد'), findsOneWidget);
    expect(
        find.text(
            'درخواست خرید با شماره PR-1403-025 ثبت و برای بررسی به مدیر مرتبط ارسال شد.'),
        findsOneWidget);
    expect(find.text('۱ قلم'), findsOneWidget);
    expect(find.text('در انتظار تأیید'), findsOneWidget);
    expect(find.text('مشاهده جزئیات درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a request saved offline says so on the success page',
      (tester) async {
    final repo = _Repo();
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    when(() => repo.create(any(), any())).thenAnswer((_) async => null);
    await tester.pumpWidget(
        _app(GenericRequestPage(repository: repo, definition: _type)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان درخواست *'), 'خرید کاغذ');
    await _tap(tester, find.text('دسته‌بندی'));
    await tester.tap(find.text('اداری').last);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('ثبت درخواست').last);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('درخواست شما روی گوشی ذخیره شد'), findsOneWidget);
    expect(find.text('مشاهده جزئیات درخواست'), findsNothing);
  });

  testWidgets('detail shows items, attachments, timeline and the menu',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    when(() => repo.detail('PR-1403-025')).thenAnswer((_) async => _request());
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    when(() => repo.cancel('PR-1403-025', reason: any(named: 'reason')))
        .thenAnswer((_) async => _request(status: 'Cancelled'));
    await tester.pumpWidget(_app(RequestDetailPage(
        name: 'PR-1403-025', repository: repo, tasks: _Tasks())));
    await tester.pumpAndSettle();

    expect(find.text('خرید لپ‌تاپ برای واحد طراحی'), findsOneWidget);
    expect(find.text('محمد رضایی'), findsOneWidget);
    expect(find.text('دسته‌بندی'), findsOneWidget); // label from the type
    expect(find.text('لپ‌تاپ Dell'), findsOneWidget);
    expect(find.text('پیش فاکتور.pdf'), findsOneWidget);
    expect(find.text('ثبت درخواست'), findsOneWidget);
    expect(find.text('تأیید مدیر مستقیم'), findsOneWidget);
    expect(find.text('در انتظار اقدام'), findsOneWidget);

    await _tap(tester, find.byTooltip('عملیات'));
    for (final item in [
      'ویرایش (قبل از تأیید)',
      'چاپ درخواست',
      'خروجی PDF',
      'مشاهده گردش کار',
      'لغو درخواست'
    ]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    await _tap(tester, find.text('لغو درخواست'));
    await tester.enterText(find.byType(TextField), 'دیگر لازم نیست');
    await _tap(
        tester,
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    verify(() => repo.cancel('PR-1403-025', reason: 'دیگر لازم نیست'))
        .called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed requests only print, export and show the workflow',
      (tester) async {
    final repo = _Repo();
    when(() => repo.detail('PR-1')).thenAnswer(
        (_) async => {..._request(status: 'Completed'), 'name': 'PR-1'});
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    await tester.pumpWidget(_app(
        RequestDetailPage(name: 'PR-1', repository: repo, tasks: _Tasks())));
    await tester.pumpAndSettle();
    expect(find.text('تکمیل شده'), findsOneWidget);
    await _tap(tester, find.byTooltip('عملیات'));
    expect(find.text('ویرایش (قبل از تأیید)'), findsNothing);
    expect(find.text('لغو درخواست'), findsNothing);
    expect(find.text('چاپ درخواست'), findsOneWidget);
  });

  testWidgets('editing sends the changed subject and values', (tester) async {
    final repo = _Repo();
    when(() => repo.detail('PR-1403-025')).thenAnswer((_) async => _request());
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    when(() => repo.update(any(), any(), any()))
        .thenAnswer((_) async => _request());
    await tester.pumpWidget(_app(RequestDetailPage(
        name: 'PR-1403-025', repository: repo, tasks: _Tasks())));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip('عملیات'));
    await _tap(tester, find.text('ویرایش (قبل از تأیید)'));
    expect(find.text('ویرایش درخواست'), findsOneWidget);
    expect(find.text('فایل یا فایل‌ها را انتخاب کنید'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان درخواست *'),
        'خرید دو لپ‌تاپ');
    await _tap(tester, find.text('ذخیره تغییرات'));
    final call =
        verify(() => repo.update('PR-1403-025', captureAny(), captureAny()));
    call.called(1);
    expect(call.captured.first, 'خرید دو لپ‌تاپ');
    expect((call.captured.last as Map)['category'], 'تجهیزات IT');
    expect(find.text('ویرایش درخواست'), findsNothing);
  });

  test('print document is a PDF with the request data', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await buildRequestPdf(
        request: _request(),
        activities: [
          WorkflowTaskActivity(
              actor: 'محمد رضایی',
              action: 'Complete',
              stageTitle: 'ثبت درخواست',
              createdOn: DateTime(2026, 9, 26))
        ],
        labels: const {'category': 'دسته‌بندی'},
        statusLabel: 'در انتظار تأیید');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(2000));
    expect(requestActionLabel('Approve'), 'تأیید');
    expect(
        requestItemRows(_request()['values'] as Map<String, dynamic>)
            .single['qty'],
        2);
  });
}
