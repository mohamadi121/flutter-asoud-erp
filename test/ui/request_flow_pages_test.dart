import 'dart:io';
import 'dart:typed_data';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
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
    when(() => repo.listPage(
            templateKey: any(named: 'templateKey'),
            statusGroup: any(named: 'statusGroup'),
            search: any(named: 'search'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            priority: any(named: 'priority'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo')))
        .thenAnswer((_) async => const RequestListPage.empty());
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
    // The detail page has its own comment box; the reason box is the dialog's.
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'دیگر لازم نیست');
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
    final text = await _pdfText(bytes);
    expect(text, contains('PR-1403-025'));
    expect(text, contains('خرید لپ تاپ برای واحد طراحی'));
    expect(text, contains('۲'));
    expect(text, contains('در انتظار تأیید'));
    expect(text, contains('محمد رضایی'));
    final second = await buildRequestPdf(request: {
      ..._request(),
      'name': 'PR-SECOND-987',
      'subject': 'Second subject',
      'values': {
        'items': [
          {'item_code': 'OTHER', 'qty': 73}
        ]
      }
    }, activities: const [], statusLabel: 'Second status');
    final secondText = await _pdfText(second);
    expect(secondText, contains('PR-SECOND-987'));
    // The producer stores the Latin words of an RTL paragraph in reverse
    // sequence, so each word is asserted separately.
    expect(secondText, contains('Second'));
    expect(secondText, contains('subject'));
    expect(secondText, contains('۷۳'));
    expect(secondText, contains('status'));
    expect(secondText, isNot(contains('PR-1403-025')));
    expect(secondText, isNot(text));
    expect(requestActionLabel('Approve'), 'تأیید');
    expect(
        requestItemRows(_request()['values'] as Map<String, dynamic>)
            .single['qty'],
        2);
  });

  testWidgets(
      'a request saved on the phone shows its local number and offers the print menu',
      (tester) async {
    final repo = _Repo();
    final local = {
      ..._request(),
      'name': 'generic-request:local',
      'local_number': 'LOCAL-12345',
      'pending_sync': true,
      'local_preview': true,
      'request_type': null,
    };
    when(() => repo.detail('generic-request:local'))
        .thenAnswer((_) async => local);
    when(() => repo.options()).thenAnswer((_) async => [_type]);
    await tester.pumpWidget(_app(RequestSubmittedPage(
        request: local, repository: repo, typeTitle: 'درخواست خرید')));
    await tester.pumpAndSettle();
    expect(find.text('درخواست شما روی گوشی ذخیره شد'), findsOneWidget);
    expect(find.textContaining('LOCAL-12345'), findsWidgets);
    await _tap(tester, find.text('مشاهده جزئیات درخواست'));
    expect(find.text('LOCAL-12345'), findsOneWidget);
    expect(find.text('ذخیره روی گوشی'), findsOneWidget);
    expect(find.text('درخواست خرید'), findsOneWidget); // title from the type
    await _tap(tester, find.byTooltip('عملیات'));
    expect(find.text('چاپ درخواست'), findsOneWidget);
    expect(find.text('خروجی PDF'), findsOneWidget);
    expect(find.text('ویرایش (قبل از تأیید)'), findsNothing);
    expect(find.text('لغو درخواست'), findsNothing);
    expect(find.text('مشاهده گردش کار'), findsNothing);
  });
}

// Reads the real page text of a PDF written by package:pdf through the
// embedded ToUnicode maps, so the assertions above inspect document content
// instead of the file header. Persian words are stored in visual order and
// are restored per word; digits and Latin tokens are kept as stored.
Future<String> _pdfText(Uint8List bytes) async {
  final raw = String.fromCharCodes(bytes);
  final fonts = <String, Map<String, String>>{};
  for (final obj in RegExp(r'(\d+) \d+ obj').allMatches(raw)) {
    final head =
        raw.substring(obj.start, (obj.start + 2000).clamp(0, raw.length));
    final name = RegExp(r'/Name/(F\d+)').firstMatch(head);
    final toUnicode = RegExp(r'/ToUnicode\s+(\d+)').firstMatch(head);
    if (name == null || toUnicode == null) continue;
    fonts[name.group(1)!] =
        _toUnicodeMap(_objectStream(raw, int.parse(toUnicode.group(1)!)));
  }
  final words = <String>[];
  var font = fonts.keys.first;
  for (final ref in RegExp(r'/Contents\s+(\d+)').allMatches(raw)) {
    final stream = _objectStream(raw, int.parse(ref.group(1)!));
    if (stream == null) continue;
    final content = String.fromCharCodes(stream);
    for (final token in RegExp(r'/F(\d+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>')
        .allMatches(content)) {
      if (token.group(1) != null) {
        font = 'F${token.group(1)}';
      } else {
        final hex = token.group(2)!;
        final glyphs = fonts[font] ?? const <String, String>{};
        final buffer = StringBuffer();
        for (var i = 0; i + 4 <= hex.length; i += 4) {
          buffer.write(_foldPresentation(
              glyphs[hex.substring(i, i + 4).toUpperCase()] ?? ''));
        }
        words.add(_toLogicalOrder(buffer.toString()));
      }
    }
  }
  return words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

// One object stream of the PDF, decompressed when it is Flate-encoded.
List<int>? _objectStream(String raw, int number) {
  final obj = RegExp('\n$number 0 obj').firstMatch(raw);
  if (obj == null) return null;
  var start = raw.indexOf('stream', obj.start) + 'stream'.length;
  if (raw[start] == '\r') start++;
  if (raw[start] == '\n') start++;
  final end = raw.indexOf('endstream', start);
  if (end < 0) return null;
  final bytes =
      raw.substring(start, end).codeUnits.map((c) => c & 0xFF).toList();
  while (bytes.isNotEmpty && (bytes.last == 0x0A || bytes.last == 0x0D)) {
    bytes.removeLast();
  }
  try {
    return ZLibDecoder().convert(bytes);
  } catch (_) {
    return null;
  }
}

// Glyph-id to Unicode mapping of one embedded font.
Map<String, String> _toUnicodeMap(List<int>? stream) {
  if (stream == null) return const {};
  final text = String.fromCharCodes(stream);
  return {
    for (final entry
        in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').allMatches(text))
      entry.group(1)!.toUpperCase(): String.fromCharCodes([
        for (var i = 0; i + 4 <= entry.group(2)!.length; i += 4)
          int.parse(entry.group(2)!.substring(i, i + 4), radix: 16),
      ]),
  };
}

// Visual (stored) order back to logical order for pure Persian words.
String _toLogicalOrder(String word) {
  if (word.isNotEmpty &&
      word.codeUnits.every(
          (c) => c >= 0x0621 && c <= 0x06D3 && !(c >= 0x0660 && c <= 0x0669))) {
    return word.split('').reversed.join();
  }
  return word;
}

// Arabic presentation forms (and related ligatures) to plain letters,
// matching Unicode NFKC folding for the embedded subset fonts.
String _foldPresentation(String value) =>
    value.split('').map((c) => _presentationFold[c] ?? c).join();

const _presentationFold = <String, String>{
  '\uFE80': '\u0621',
  '\uFE81': '\u0622',
  '\uFE82': '\u0622',
  '\uFE83': '\u0623',
  '\uFE84': '\u0623',
  '\uFE85': '\u0624',
  '\uFE86': '\u0624',
  '\uFE87': '\u0625',
  '\uFE88': '\u0625',
  '\uFE89': '\u0626',
  '\uFE8A': '\u0626',
  '\uFE8B': '\u0626',
  '\uFE8C': '\u0626',
  '\uFE8D': '\u0627',
  '\uFE8E': '\u0627',
  '\uFE8F': '\u0628',
  '\uFE90': '\u0628',
  '\uFE91': '\u0628',
  '\uFE92': '\u0628',
  '\uFE93': '\u0629',
  '\uFE94': '\u0629',
  '\uFE95': '\u062A',
  '\uFE96': '\u062A',
  '\uFE97': '\u062A',
  '\uFE98': '\u062A',
  '\uFE99': '\u062B',
  '\uFE9A': '\u062B',
  '\uFE9B': '\u062B',
  '\uFE9C': '\u062B',
  '\uFE9D': '\u062C',
  '\uFE9E': '\u062C',
  '\uFE9F': '\u062C',
  '\uFEA0': '\u062C',
  '\uFEA1': '\u062D',
  '\uFEA2': '\u062D',
  '\uFEA3': '\u062D',
  '\uFEA4': '\u062D',
  '\uFEA5': '\u062E',
  '\uFEA6': '\u062E',
  '\uFEA7': '\u062E',
  '\uFEA8': '\u062E',
  '\uFEA9': '\u062F',
  '\uFEAA': '\u062F',
  '\uFEAB': '\u0630',
  '\uFEAC': '\u0630',
  '\uFEAD': '\u0631',
  '\uFEAE': '\u0631',
  '\uFEAF': '\u0632',
  '\uFEB0': '\u0632',
  '\uFEB1': '\u0633',
  '\uFEB2': '\u0633',
  '\uFEB3': '\u0633',
  '\uFEB4': '\u0633',
  '\uFEB5': '\u0634',
  '\uFEB6': '\u0634',
  '\uFEB7': '\u0634',
  '\uFEB8': '\u0634',
  '\uFEB9': '\u0635',
  '\uFEBA': '\u0635',
  '\uFEBB': '\u0635',
  '\uFEBC': '\u0635',
  '\uFEBD': '\u0636',
  '\uFEBE': '\u0636',
  '\uFEBF': '\u0636',
  '\uFEC0': '\u0636',
  '\uFEC1': '\u0637',
  '\uFEC2': '\u0637',
  '\uFEC3': '\u0637',
  '\uFEC4': '\u0637',
  '\uFEC5': '\u0638',
  '\uFEC6': '\u0638',
  '\uFEC7': '\u0638',
  '\uFEC8': '\u0638',
  '\uFEC9': '\u0639',
  '\uFECA': '\u0639',
  '\uFECB': '\u0639',
  '\uFECC': '\u0639',
  '\uFECD': '\u063A',
  '\uFECE': '\u063A',
  '\uFECF': '\u063A',
  '\uFED0': '\u063A',
  '\uFED1': '\u0641',
  '\uFED2': '\u0641',
  '\uFED3': '\u0641',
  '\uFED4': '\u0641',
  '\uFED5': '\u0642',
  '\uFED6': '\u0642',
  '\uFED7': '\u0642',
  '\uFED8': '\u0642',
  '\uFED9': '\u0643',
  '\uFEDA': '\u0643',
  '\uFEDB': '\u0643',
  '\uFEDC': '\u0643',
  '\uFEDD': '\u0644',
  '\uFEDE': '\u0644',
  '\uFEDF': '\u0644',
  '\uFEE0': '\u0644',
  '\uFEE1': '\u0645',
  '\uFEE2': '\u0645',
  '\uFEE3': '\u0645',
  '\uFEE4': '\u0645',
  '\uFEE5': '\u0646',
  '\uFEE6': '\u0646',
  '\uFEE7': '\u0646',
  '\uFEE8': '\u0646',
  '\uFEE9': '\u0647',
  '\uFEEA': '\u0647',
  '\uFEEB': '\u0647',
  '\uFEEC': '\u0647',
  '\uFEED': '\u0648',
  '\uFEEE': '\u0648',
  '\uFEEF': '\u0649',
  '\uFEF0': '\u0649',
  '\uFEF1': '\u064A',
  '\uFEF2': '\u064A',
  '\uFEF3': '\u064A',
  '\uFEF4': '\u064A',
  '\uFEF5': '\u0644\u0622',
  '\uFEF6': '\u0644\u0622',
  '\uFEF7': '\u0644\u0623',
  '\uFEF8': '\u0644\u0623',
  '\uFEF9': '\u0644\u0625',
  '\uFEFA': '\u0644\u0625',
  '\uFEFB': '\u0644\u0627',
  '\uFEFC': '\u0644\u0627',
  '\uFB50': '\u0671',
  '\uFB51': '\u0671',
  '\uFB52': '\u067B',
  '\uFB53': '\u067B',
  '\uFB54': '\u067B',
  '\uFB55': '\u067B',
  '\uFB56': '\u067E',
  '\uFB57': '\u067E',
  '\uFB58': '\u067E',
  '\uFB59': '\u067E',
  '\uFB5A': '\u0680',
  '\uFB5B': '\u0680',
  '\uFB5C': '\u0680',
  '\uFB5D': '\u0680',
  '\uFB5E': '\u067A',
  '\uFB5F': '\u067A',
  '\uFB60': '\u067A',
  '\uFB61': '\u067A',
  '\uFB62': '\u067F',
  '\uFB63': '\u067F',
  '\uFB64': '\u067F',
  '\uFB65': '\u067F',
  '\uFB66': '\u0679',
  '\uFB67': '\u0679',
  '\uFB68': '\u0679',
  '\uFB69': '\u0679',
  '\uFB6A': '\u06A4',
  '\uFB6B': '\u06A4',
  '\uFB6C': '\u06A4',
  '\uFB6D': '\u06A4',
  '\uFB6E': '\u06A6',
  '\uFB6F': '\u06A6',
  '\uFB70': '\u06A6',
  '\uFB71': '\u06A6',
  '\uFB72': '\u0684',
  '\uFB73': '\u0684',
  '\uFB74': '\u0684',
  '\uFB75': '\u0684',
  '\uFB76': '\u0683',
  '\uFB77': '\u0683',
  '\uFB78': '\u0683',
  '\uFB79': '\u0683',
  '\uFB7A': '\u0686',
  '\uFB7B': '\u0686',
  '\uFB7C': '\u0686',
  '\uFB7D': '\u0686',
  '\uFB7E': '\u0687',
  '\uFB7F': '\u0687',
  '\uFB80': '\u0687',
  '\uFB81': '\u0687',
  '\uFB82': '\u068D',
  '\uFB83': '\u068D',
  '\uFB84': '\u068C',
  '\uFB85': '\u068C',
  '\uFB86': '\u068E',
  '\uFB87': '\u068E',
  '\uFB88': '\u0688',
  '\uFB89': '\u0688',
  '\uFB8A': '\u0698',
  '\uFB8B': '\u0698',
  '\uFB8C': '\u0691',
  '\uFB8D': '\u0691',
  '\uFB8E': '\u06A9',
  '\uFB8F': '\u06A9',
  '\uFB90': '\u06A9',
  '\uFB91': '\u06A9',
  '\uFB92': '\u06AF',
  '\uFB93': '\u06AF',
  '\uFB94': '\u06AF',
  '\uFB95': '\u06AF',
  '\uFB96': '\u06B3',
  '\uFB97': '\u06B3',
  '\uFB98': '\u06B3',
  '\uFB99': '\u06B3',
  '\uFB9A': '\u06B1',
  '\uFB9B': '\u06B1',
  '\uFB9C': '\u06B1',
  '\uFB9D': '\u06B1',
  '\uFB9E': '\u06BA',
  '\uFB9F': '\u06BA',
  '\uFBA0': '\u06BB',
  '\uFBA1': '\u06BB',
  '\uFBA2': '\u06BB',
  '\uFBA3': '\u06BB',
  '\uFBA4': '\u06C0',
  '\uFBA5': '\u06C0',
  '\uFBA6': '\u06C1',
  '\uFBA7': '\u06C1',
  '\uFBA8': '\u06C1',
  '\uFBA9': '\u06C1',
  '\uFBAA': '\u06BE',
  '\uFBAB': '\u06BE',
  '\uFBAC': '\u06BE',
  '\uFBAD': '\u06BE',
  '\uFBAE': '\u06D2',
  '\uFBAF': '\u06D2',
  '\uFBB0': '\u06D3',
  '\uFBB1': '\u06D3',
  '\uFBD3': '\u06AD',
  '\uFBD4': '\u06AD',
  '\uFBD5': '\u06AD',
  '\uFBD6': '\u06AD',
  '\uFBD7': '\u06C7',
  '\uFBD8': '\u06C7',
  '\uFBD9': '\u06C6',
  '\uFBDA': '\u06C6',
  '\uFBDB': '\u06C8',
  '\uFBDC': '\u06C8',
  '\uFBDD': '\u06C7\u0674',
  '\uFBDE': '\u06CB',
  '\uFBDF': '\u06CB',
  '\uFBE0': '\u06C5',
  '\uFBE1': '\u06C5',
  '\uFBE2': '\u06C9',
  '\uFBE3': '\u06C9',
  '\uFBE4': '\u06D0',
  '\uFBE5': '\u06D0',
  '\uFBE6': '\u06D0',
  '\uFBE7': '\u06D0',
  '\uFBE8': '\u0649',
  '\uFBE9': '\u0649',
  '\uFBEA': '\u0626\u0627',
  '\uFBEB': '\u0626\u0627',
  '\uFBEC': '\u0626\u06D5',
  '\uFBED': '\u0626\u06D5',
  '\uFBEE': '\u0626\u0648',
  '\uFBEF': '\u0626\u0648',
  '\uFBF0': '\u0626\u06C7',
  '\uFBF1': '\u0626\u06C7',
  '\uFBF2': '\u0626\u06C6',
  '\uFBF3': '\u0626\u06C6',
  '\uFBF4': '\u0626\u06C8',
  '\uFBF5': '\u0626\u06C8',
  '\uFBF6': '\u0626\u06D0',
  '\uFBF7': '\u0626\u06D0',
  '\uFBF8': '\u0626\u06D0',
  '\uFBF9': '\u0626\u0649',
  '\uFBFA': '\u0626\u0649',
  '\uFBFB': '\u0626\u0649',
  '\uFBFC': '\u06CC',
  '\uFBFD': '\u06CC',
  '\uFBFE': '\u06CC',
  '\uFBFF': '\u06CC',
};
