import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.detailMap);
  Map<String, dynamic> detailMap;
  List<Map<String, dynamic>> thread =
      (requestData('list_comments') as List).cast<Map<String, dynamic>>();
  final added = <String>[];
  final cancelled = <String>[];
  final thumbnails = <String>[];
  final downloads = <String>[];
  Object? cancelFailure;
  Object? addFailure;
  int loads = 0;

  @override
  Future<Map<String, dynamic>> detail(String name) async {
    loads++;
    return Map<String, dynamic>.from(detailMap);
  }

  @override
  Future<List<Map<String, dynamic>>> options() async => requestOptionFixtures();

  @override
  Future<List<RequestComment>> comments(String name) async => [
        for (final row in thread) RequestComment.fromMap(row),
      ];

  @override
  Future<RequestComment> addComment(String name, String text) async {
    added.add(text);
    if (addFailure != null) throw addFailure!;
    return RequestComment(
        name: 'new',
        content: text,
        authorName: 'سارا محمدی',
        creation: '2026-10-06 09:00:00',
        isMine: true);
  }

  @override
  Future<Map<String, dynamic>> cancel(String name, {String reason = ''}) async {
    cancelled.add(reason);
    if (cancelFailure != null) throw cancelFailure!;
    detailMap = {
      ...detailMap,
      'status_key': 'cancelled',
      'status_label': 'لغو شده',
      'can_edit': false,
      'can_cancel': false
    };
    return detailMap;
  }

  @override
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
      String name,
      {bool thumbnail = false}) async {
    (thumbnail ? thumbnails : downloads).add(name);
    final data = requestData('get_attachment') as Map;
    return (
      filename: '${data['filename']}',
      contentType: '${data['content_type']}',
      bytes: base64Decode('${data['content_base64']}')
    );
  }
}

Map<String, dynamic> _fixture(String name) =>
    Map<String, dynamic>.from(requestData(name) as Map);

Future<void> _open(WidgetTester tester, _Repo repo,
    {RequestDetailSlot? info,
    RequestDetailSlot? items,
    List<Widget> Function(BuildContext, RequestDetailView)? extra,
    List<(String, Uint8List)>? saved}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox()); // a fresh page for every request
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RequestDetailScaffold(
        repository: repo,
        name: '${repo.detailMap['name']}',
        title: 'جزئیات درخواست خرید',
        infoBuilder: info,
        itemsBuilder: items,
        extraSections: extra,
        fileSaver: (name, bytes) async => saved?.add((name, bytes)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RequestScreenRegistry.clear);

  testWidgets('shows the status, info, items with thumbnails and the actions',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    expect(find.text('جزئیات درخواست خرید'), findsOneWidget);
    expect(find.text('PR-1405-0023'), findsOneWidget);
    expect(find.text('ارسال شده'), findsOneWidget);
    expect(find.text('خرید تجهیزات ICU'), findsOneWidget);
    expect(find.text('سارا محمدی'), findsOneWidget);
    expect(find.text('درخواست خرید کالا'), findsOneWidget);
    expect(find.text('اقلام درخواست (۱ قلم)'), findsOneWidget);
    expect(find.text('مانیتور ICU'), findsOneWidget);
    expect(find.text('ICU-MON-01'), findsOneWidget);
    expect(find.text('عادی'), findsNothing);
    expect(find.text('مهم'), findsOneWidget, reason: 'Choice label of High');
    expect(find.text(formatJalaliIso('2026-10-20')), findsOneWidget);
    expect(repo.thumbnails, ['1a2b3c']);
    expect(find.byKey(const ValueKey('thumb:1a2b3c')), findsOneWidget);
    expect(find.text('نظرات'), findsOneWidget);
    expect(find.text('لطفاً پیش‌فاکتور را پیوست کنید.'), findsOneWidget);
    expect(find.text('احمد رضایی'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-edit-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('request-cancel-button')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('request-copy-link-button')), findsOneWidget);
    expect(find.text('ویرایش'), findsOneWidget);
    expect(find.text('انصراف درخواست'), findsOneWidget);
    expect(find.text('کپی لینک'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '«ویرایش» only when can_edit, «انصراف درخواست» only when can_cancel',
      (tester) async {
    for (final (edit, cancel) in [
      (true, true),
      (true, false),
      (false, true),
      (false, false)
    ]) {
      final repo = _Repo({
        ..._fixture('get_request_purchase'),
        'can_edit': edit,
        'can_cancel': cancel
      });
      await _open(tester, repo);
      expect(find.text('ویرایش'), edit ? findsOneWidget : findsNothing,
          reason: 'edit $edit/$cancel');
      expect(
          find.text('انصراف درخواست'), cancel ? findsOneWidget : findsNothing,
          reason: 'cancel $edit/$cancel');
      expect(find.text('کپی لینک'), findsOneWidget);
      await tester.tap(find.byTooltip('عملیات'));
      await tester.pumpAndSettle();
      expect(find.text('ویرایش (قبل از تأیید)'),
          edit ? findsOneWidget : findsNothing);
      expect(find.text('لغو درخواست'), cancel ? findsOneWidget : findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('«کپی لینک» copies asoud://request/<name>', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    await tester.tap(find.text('کپی لینک'));
    await tester.pumpAndSettle();
    expect(copied, ['asoud://request/PR-1405-0023']);
    expect(parseRequestLink(copied.single), 'PR-1405-0023');
    expect(find.text('لینک درخواست کپی شد.'), findsOneWidget);
  });

  testWidgets('comments are posted and shown', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    await tester.enterText(
        find.byKey(const ValueKey('request-comment-input')), '  پیوست شد  ');
    await tester.tap(find.byTooltip('ارسال نظر'));
    await tester.pumpAndSettle();
    expect(repo.added, ['پیوست شد']);
    expect(find.text('پیوست شد'), findsOneWidget);
    expect(find.text('لطفاً پیش‌فاکتور را پیوست کنید.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('request-comment-input')))
            .controller!
            .text,
        isEmpty);
    // An empty box sends nothing.
    await tester.tap(find.byTooltip('ارسال نظر'));
    await tester.pumpAndSettle();
    expect(repo.added, hasLength(1));
  });

  testWidgets('an offline comment is marked «در انتظار ارسال»', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    repo.thread = [];
    await tester.enterText(
        find.byKey(const ValueKey('request-comment-input')), 'بعداً');
    await tester.tap(find.byTooltip('ارسال نظر'));
    await tester.pumpAndSettle();
    expect(find.text('بعداً'), findsOneWidget);

    repo.addFailure = const ApiException(
        kind: ApiFailureKind.forbidden,
        message: 'اجازه انجام این عملیات را ندارید.');
    await tester.enterText(
        find.byKey(const ValueKey('request-comment-input')), 'ممنوع');
    await tester.tap(find.byTooltip('ارسال نظر'));
    await tester.pumpAndSettle();
    expect(find.text('اجازه انجام این عملیات را ندارید.'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(2),
        reason: 'the first comment and «بعداً»; «ممنوع» was not added');
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('request-comment-input')))
            .controller!
            .text,
        'ممنوع',
        reason: 'the text stays to be sent again');
  });

  testWidgets('a queued comment shows the pending marker', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    repo.thread = [
      {
        'name': 'local',
        'content': 'در صف',
        'author': 'sara@x',
        'author_name': 'سارا محمدی',
        'creation': '2026-10-06 09:00:00',
        'is_mine': true,
        'pending': true
      }
    ];
    await _open(tester, repo);
    expect(find.text('در صف'), findsOneWidget);
    expect(find.text('در انتظار ارسال'), findsOneWidget);
  });

  testWidgets('cancel asks for a reason and handles every outcome',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'دیگر لازم نیست');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(repo.cancelled, ['دیگر لازم نیست']);
    expect(find.text('درخواست لغو شد.'), findsOneWidget);
    expect(find.text('لغو شده'), findsOneWidget, reason: 'reloaded');
    expect(find.text('انصراف درخواست'), findsNothing);
    expect(find.text('ویرایش'), findsNothing);
  });

  testWidgets('a cancel that is queued offline says so', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'))
      ..cancelFailure = const QueuedOfflineException(localId: 'q');
    await _open(tester, repo);
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('ذخیره شد؛ پس از اتصال ارسال می‌شود'), findsOneWidget);
  });

  testWidgets('a second cancel counts as done once the request is cancelled',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'))
      ..cancelFailure = const ApiException(
          kind: ApiFailureKind.validation,
          statusCode: 417,
          message: 'Only a request in progress can be changed');
    await _open(tester, repo);
    // Meanwhile another device cancelled it.
    repo.detailMap = {
      ...repo.detailMap,
      'status_key': 'cancelled',
      'status_label': 'لغو شده',
      'can_cancel': false,
      'can_edit': false
    };
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('درخواست لغو شده است.'), findsOneWidget);
    expect(find.textContaining('Only a request'), findsNothing);
  });

  testWidgets('a cancel the server refuses shows its message', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'))
      ..cancelFailure = const ApiException(
          kind: ApiFailureKind.validation,
          statusCode: 417,
          message: 'درخواست قابل تغییر نیست.');
    await _open(tester, repo);
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('درخواست قابل تغییر نیست.'), findsOneWidget);
  });

  testWidgets('«ویرایش» opens the registered form and reloads after a save',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    Map<String, dynamic>? seenType, seenExisting;
    RequestScreenRegistry.register('purchase',
        RequestTemplateScreens(form: (context, repository, type, existing) {
      seenType = type;
      seenExisting = existing;
      return Scaffold(
          body: Center(
              child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ذخیره'))));
    }));
    await _open(tester, repo);
    final before = repo.loads;
    await tester.tap(find.byKey(const ValueKey('request-edit-button')));
    await tester.pumpAndSettle();
    expect(seenType!['template_key'], 'purchase');
    expect(seenExisting!['name'], 'PR-1405-0023');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(repo.loads, before + 1);
  });

  testWidgets('files are listed and downloaded', (tester) async {
    final saved = <(String, Uint8List)>[];
    final repo = _Repo({
      ..._fixture('get_request_purchase'),
      'attachments': [
        {
          'name': 'F-9',
          'filename': 'price.pdf',
          'file_url': '/private/files/price.pdf',
          'size': 1258291,
          'content_type': 'application/pdf',
          'is_image': false,
          'scope': 'general'
        },
        {
          'name': '1a2b3c',
          'filename': 'm.png',
          'file_url': '/private/files/m.png',
          'size': 18211,
          'content_type': 'image/png',
          'is_image': true,
          'scope': 'row:items:0'
        },
      ],
    });
    await _open(tester, repo, saved: saved);
    expect(find.text('پیوست‌ها (۱ فایل)'), findsOneWidget,
        reason: 'row files belong to their row');
    expect(find.text('price.pdf'), findsOneWidget);
    expect(find.text('۱٫۲ مگابایت'), findsOneWidget);
    await tester.tap(find.byTooltip('دریافت فایل'));
    await tester.pumpAndSettle();
    expect(repo.downloads, ['F-9']);
    expect(saved.single.$1, 'm.png');
    expect(saved.single.$2, isNotEmpty);
  });

  testWidgets('a request without files says so (templates only)',
      (tester) async {
    final repo = _Repo(_fixture('get_request_leave_daily'));
    await _open(tester, repo);
    expect(find.text('فایلی وجود ندارد.'), findsOneWidget);
  });

  testWidgets('leave detail formats dates, times and labels', (tester) async {
    final repo = _Repo(_fixture('get_request_leave_hourly'));
    await _open(tester, repo);
    expect(find.text('LV-1405-0041'), findsOneWidget);
    expect(find.text('ساعتی'), findsOneWidget, reason: 'Choice label');
    expect(find.text('۱۰:۰۰'), findsOneWidget);
    expect(find.text('۱۴:۰۰'), findsOneWidget);
    expect(find.text(formatJalaliIso('2026-10-06')), findsOneWidget);
    expect(find.text('مراجعه به بیمارستان برای معاینه پزشک'), findsOneWidget);
    expect(find.text('مدت مرخصی'), findsNothing,
        reason: 'Auto fields are not stored values');
    await tester.pumpWidget(const SizedBox());
    final daily = _Repo(_fixture('get_request_leave_daily'));
    await _open(tester, daily);
    expect(find.text('روزانه'), findsOneWidget);
    expect(find.text(formatJalaliIso('2026-10-10')), findsOneWidget);
    expect(find.text(formatJalaliIso('2026-10-12')), findsOneWidget);
    expect(find.text('تأیید شده'), findsOneWidget);
    expect(find.text('ویرایش'), findsNothing);
    expect(find.text('انصراف درخواست'), findsNothing);
  });

  testWidgets('a rejected request shows the reason', (tester) async {
    final repo = _Repo(_fixture('get_request_leave_rejected'));
    await _open(tester, repo);
    expect(find.text('رد شده'), findsOneWidget);
    expect(find.text('دلیل رد: به دلیل مدارک ناقص'), findsOneWidget);
  });

  testWidgets('the native document chip follows native.status', (tester) async {
    for (final (status, label) in [
      ('Created', 'سند ERP ایجاد شد'),
      ('Pending', 'در انتظار ایجاد سند ERP'),
      ('Failed', 'ایجاد سند ERP ناموفق بود'),
    ]) {
      final repo = _Repo({
        ..._fixture('get_request_purchase'),
        'status_key': 'approved',
        'status_label': 'تأیید شده',
        'native': {
          'doctype': 'Material Request',
          'name': 'MAT-0001',
          'status': status,
          'error': status == 'Failed' ? 'انبار تعریف نشده است.' : ''
        },
      });
      await _open(tester, repo);
      expect(find.text('تأیید شده'), findsOneWidget, reason: status);
      expect(find.text(label), findsOneWidget, reason: status);
      expect(find.text('انبار تعریف نشده است.'),
          status == 'Failed' ? findsOneWidget : findsNothing);
    }
    final skipped = _Repo({
      ..._fixture('get_request_purchase'),
      'native': {'doctype': '', 'name': '', 'status': 'Skipped', 'error': ''}
    });
    await _open(tester, skipped);
    expect(find.textContaining('سند ERP'), findsNothing);
  });

  testWidgets('slots replace the info and items cards and add sections',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo,
        info: (context, view) => Text('اطلاعات ${view.detail.number}'),
        items: (context, view) => Text('اقلام ${view.detail.items.length}'),
        extra: (context, view) => [Text('بخش اضافه ${view.typeTitle}')]);
    expect(find.text('اطلاعات PR-1405-0023'), findsOneWidget);
    expect(find.text('اقلام 1'), findsOneWidget);
    expect(find.text('بخش اضافه درخواست خرید کالا'), findsOneWidget);
    expect(find.text('مانیتور ICU'), findsNothing);
    expect(find.text('درخواست‌کننده'), findsNothing);
  });

  testWidgets('a request waiting on the device has no actions or comments',
      (tester) async {
    final repo = _Repo({
      ..._fixture('get_request_purchase'),
      'name': 'generic-request:x',
      'pending_sync': true,
      'status_key': 'submitted',
      'can_edit': false,
      'can_cancel': false,
    });
    await _open(tester, repo);
    expect(find.text('در انتظار همگام‌سازی'), findsOneWidget);
    expect(find.text('کپی لینک'), findsNothing);
    expect(find.text('ویرایش'), findsNothing);
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('request-comment-input')))
            .enabled,
        isFalse);
  });

  testWidgets('renders at 320 without overflow', (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await tester.binding.setSurfaceSize(const Size(320, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: RequestDetailScaffold(
                repository: repo, name: 'PR-1405-0023'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('bottom bar', () {
    Future<void> check(WidgetTester tester, double width,
        {required bool edit, required bool cancel}) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repo({
        ..._fixture('get_request_purchase'),
        'can_edit': edit,
        'can_cancel': cancel,
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
              textDirection: TextDirection.rtl,
              child: RequestDetailScaffold(
                  repository: repo, name: 'PR-1405-0023'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final labels = [
        'کپی لینک',
        if (edit) 'ویرایش',
        if (cancel) 'انصراف درخواست',
      ];
      final rects = <Rect>[];
      for (final label in labels) {
        final button = find.ancestor(
            of: find.text(label), matching: find.byType(OutlinedButton));
        expect(button, findsOneWidget, reason: label);
        rects.add(tester.getRect(button));
        // One line: a single text box, and not taller than one text line.
        final paragraph =
            tester.renderObject<RenderParagraph>(find.text(label));
        final lines = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length));
        expect(lines, hasLength(1), reason: '$label at $width');
        expect(paragraph.size.height, lessThan(30), reason: '$label at $width');
        // The label stays inside its button.
        final text = tester.getRect(find.text(label));
        expect(rects.last.contains(text.center), isTrue, reason: label);
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse,
              reason: '${labels[i]} overlaps ${labels[j]} at $width');
        }
        expect(rects[i].left, greaterThanOrEqualTo(0));
        expect(rects[i].right, lessThanOrEqualTo(width));
      }
    }

    testWidgets('three buttons keep every label on one line at 390 and 360',
        (tester) async {
      await check(tester, 390, edit: true, cancel: true);
      await check(tester, 360, edit: true, cancel: true);
    });

    testWidgets('two buttons do too', (tester) async {
      await check(tester, 390, edit: true, cancel: false);
      await check(tester, 360, edit: false, cancel: true);
      await check(tester, 360, edit: false, cancel: false);
    });
  });

  testWidgets('the items card is titled «اقلام درخواست (N قلم)»',
      (tester) async {
    final repo = _Repo(_fixture('get_request_purchase'));
    await _open(tester, repo);
    expect(find.text('اقلام درخواست (۱ قلم)'), findsOneWidget);
    expect(find.textContaining('اقلام درخواستی'), findsNothing);
  });

  testWidgets('a StateError or ApiException of cancel shows its own message',
      (tester) async {
    for (final failure in <Object>[
      StateError('درخواست نمایشی قابل لغو نیست؛ یک درخواست جدید ثبت کنید.'),
      const ApiException(
          kind: ApiFailureKind.validation,
          statusCode: 417,
          message: 'درخواست قابل تغییر نیست.'),
    ]) {
      final repo = _Repo(_fixture('get_request_purchase'))
        ..cancelFailure = failure;
      await _open(tester, repo);
      await tester.tap(find.text('انصراف درخواست'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      final message = failure is StateError
          ? failure.message
          : (failure as ApiException).message;
      expect(find.text(message), findsOneWidget);
      expect(find.text('لغو درخواست انجام نشد.'), findsNothing);
    }
    // Anything else keeps the generic text.
    final repo = _Repo(_fixture('get_request_purchase'))
      ..cancelFailure = Exception('boom');
    await _open(tester, repo);
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('لغو درخواست انجام نشد.'), findsOneWidget);
  });
}
