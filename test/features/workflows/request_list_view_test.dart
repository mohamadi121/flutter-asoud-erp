
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

class _Query {
  _Query(this.templateKey, this.statusGroup, this.search, this.offset,
      this.limit, this.priority, this.dateFrom, this.dateTo);
  final String? templateKey, priority, dateFrom, dateTo;
  final String statusGroup, search;
  final int offset, limit;
}

/// A repository that serves [rows] with the server's filtering rules.
class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.rows);
  List<Map<String, dynamic>> rows;
  final queries = <_Query>[];
  Object? failure;
  bool hasPending = false;
  int syncs = 0;

  @override
  Future<RequestListPage> listPage({
    String? templateKey,
    String statusGroup = 'all',
    String search = '',
    int offset = 0,
    int limit = 20,
    String? priority,
    String? dateFrom,
    String? dateTo,
  }) async {
    queries.add(_Query(templateKey, statusGroup, search, offset, limit,
        priority, dateFrom, dateTo));
    if (failure != null) throw failure!;
    final all = [for (final row in rows) RequestSummary.fromMap(row)];
    bool match(RequestSummary row, {bool status = true}) =>
        (templateKey == null || row.templateKey == templateKey) &&
        (!status || statusGroup == 'all' || row.statusGroup == statusGroup) &&
        (priority == null || row.priority == priority) &&
        (search.isEmpty || row.subject.contains(search));
    final shown = all.where(match).toList();
    final context = all.where((row) => match(row, status: false)).toList();
    return RequestListPage(
      items: shown.skip(offset).take(limit).toList(),
      total: shown.length,
      offset: offset,
      counts: {
        'all': context.length,
        for (final group in ['pending', 'approved', 'rejected'])
          group: context.where((row) => row.statusGroup == group).length,
      },
    );
  }

  @override
  Future<List<LocalRecord>> pending() async => hasPending
      ? [
          LocalRecord(
              id: 'x',
              entityType: 'generic_request_outbox',
              payload: const {},
              status: LocalSyncStatus.pendingSync,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now())
        ]
      : [];

  @override
  Future<void> sync({bool retry = false}) async => syncs++;
}

List<Map<String, dynamic>> _fixtureRows() => [
      for (final row in (requestFixture('list_all') as Map)['data'] as List)
        Map<String, dynamic>.from(row as Map)
    ];

Widget _app(Widget page) => MaterialApp(theme: AsoudTheme.light, home: page);

Future<void> _open(WidgetTester tester, _Repo repo,
    {String? templateKey,
    Widget Function(BuildContext, RequestSummary)? cardBuilder,
    Future<void> Function(RequestSummary)? onOpen,
    VoidCallback? onCreate,
    String? createLabel}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(RequestListView(
    repository: repo,
    title: 'درخواست‌های خرید',
    templateKey: templateKey,
    cardBuilder: cardBuilder,
    onOpen: onOpen,
    onCreate: onCreate,
    createLabel: createLabel,
  )));
  await tester.pumpAndSettle();
}

String _count(WidgetTester tester, String group) {
  final tab = find.byKey(ValueKey('request-tab:$group'));
  final texts = tester
      .widgetList<Text>(find.descendant(of: tab, matching: find.byType(Text)))
      .map((text) => text.data)
      .toList();
  return texts.last!;
}

void main() {
  setUp(RequestScreenRegistry.clear);

  testWidgets('shows the tabs with the server counts and the default cards',
      (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo);
    expect(find.text('درخواست‌های خرید'), findsOneWidget);
    for (final label in ['همه', 'در انتظار بررسی', 'تأیید شده', 'رد شده']) {
      expect(
          find.descendant(
              of: find.byKey(ValueKey('request-tab:${{
                'همه': 'all',
                'در انتظار بررسی': 'pending',
                'تأیید شده': 'approved',
                'رد شده': 'rejected'
              }[label]}')),
              matching: find.text(label)),
          findsOneWidget,
          reason: label);
    }
    expect(_count(tester, 'all'), '۴');
    expect(_count(tester, 'pending'), '۲');
    expect(_count(tester, 'approved'), '۱');
    expect(_count(tester, 'rejected'), '۱');
    expect(find.text('خرید تجهیزات ICU'), findsOneWidget);
    expect(find.text('PR-1405-0023'), findsOneWidget);
    expect(find.text('ارسال شده'), findsOneWidget, reason: 'status chip');
    expect(find.text('سارا محمدی'), findsWidgets);
    expect(find.text('۳ قلم'), findsOneWidget);
    expect(repo.queries.single.statusGroup, 'all');
    expect(repo.queries.single.limit, 20);
    expect(find.byTooltip('درخواست جدید'), findsNothing);
  });

  testWidgets('a tab asks the server for that status group', (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo);
    await tester.tap(find.byKey(const ValueKey('request-tab:approved')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.statusGroup, 'approved');
    expect(find.text('خرید لوازم مصرفی اداری'), findsOneWidget);
    expect(find.text('خرید تجهیزات ICU'), findsNothing);
    expect(_count(tester, 'all'), '۴', reason: 'counts ignore the tab');
    await tester.tap(find.byKey(const ValueKey('request-tab:rejected')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.statusGroup, 'rejected');
    expect(find.text('خرید مبلمان اداری'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('request-tab:all')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.statusGroup, 'all');
    expect(find.text('خرید مبلمان اداری'), findsOneWidget);
    expect(find.text('خرید تجهیزات ICU'), findsOneWidget);
  });

  testWidgets('the template key reaches the repository and a change reloads',
      (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo, templateKey: 'purchase');
    expect(repo.queries.last.templateKey, 'purchase');
    await tester.pumpWidget(_app(RequestListView(
        repository: repo, title: 'درخواست‌های مرخصی', templateKey: 'leave')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.templateKey, 'leave');
    expect(find.text('موردی با این جستجو یا فیلتر پیدا نشد.'), findsNothing);
    expect(find.text('هنوز درخواستی ثبت نشده است.'), findsOneWidget);
  });

  testWidgets('search is debounced (400 ms) and sent once', (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo);
    final before = repo.queries.length;
    final box = find.byType(TextField).first;
    await tester.enterText(box, 'ک');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(box, 'کا');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(box, 'کابل');
    await tester.pump(const Duration(milliseconds: 399));
    expect(repo.queries.length, before, reason: 'still waiting');
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    expect(repo.queries.length, before + 1);
    expect(repo.queries.last.search, 'کابل');
    expect(find.text('کابل و متریال شبکه'), findsOneWidget);
    expect(find.text('خرید تجهیزات ICU'), findsNothing);
    // No match: the search empty state, not the "nothing yet" one.
    await tester.enterText(box, 'zzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('موردی با این جستجو یا فیلتر پیدا نشد.'), findsOneWidget);
    expect(find.text('هنوز درخواستی ثبت نشده است.'), findsNothing);
  });

  List<Map<String, dynamic>> manyRows() => [
        for (var i = 0; i < 45; i++)
          {
            ..._fixtureRows().first,
            'name': 'PR-1405-${1000 + i}',
            'number': 'PR-1405-${1000 + i}',
            'subject': 'درخواست شماره $i',
          }
      ];

  testWidgets('more pages are loaded with the button', (tester) async {
    final repo = _Repo(manyRows());
    await tester.binding.setSurfaceSize(const Size(390, 9000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        _app(RequestListView(repository: repo, title: 'درخواست‌ها')));
    await tester.pumpAndSettle();
    expect(repo.queries.single.offset, 0);
    expect(repo.queries.single.limit, 20);
    expect(find.text('درخواست شماره 19'), findsOneWidget);
    expect(find.text('درخواست شماره 20'), findsNothing);
    await tester.tap(find.text('نمایش بیشتر'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.offset, 20);
    expect(find.text('درخواست شماره 20'), findsOneWidget);
    expect(find.text('درخواست شماره 39'), findsOneWidget);
    await tester.tap(find.text('نمایش بیشتر'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.offset, 40);
    expect(find.text('درخواست شماره 44'), findsOneWidget);
    expect(find.text('نمایش بیشتر'), findsNothing, reason: 'all 45 are loaded');
    expect(repo.queries.map((q) => q.offset), [0, 20, 40]);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final repo = _Repo(manyRows());
    await _open(tester, repo);
    expect(repo.queries.map((q) => q.offset), [0]);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(repo.queries.map((q) => q.offset), contains(20));
  });

  testWidgets('the filter sheet sends priority and dates and can be cleared',
      (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo);
    await tester.tap(find.byTooltip('فیلتر'));
    await tester.pumpAndSettle();
    expect(find.text('فیلتر درخواست‌ها'), findsOneWidget);
    for (final label in ['عادی', 'مهم', 'فوری']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'مهم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعمال فیلتر'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.priority, 'High');
    expect(find.byType(Badge), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    await tester.tap(find.byTooltip('فیلتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف فیلتر'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.priority, isNull);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('empty and error states offer a retry', (tester) async {
    final repo = _Repo([])..failure = StateError('boom');
    await _open(tester, repo);
    expect(find.text('تلاش دوباره'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز درخواستی ثبت نشده است.'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });

  testWidgets('a custom empty text and card builder are used', (tester) async {
    final repo = _Repo(_fixtureRows());
    await _open(tester, repo,
        cardBuilder: (context, row) => Text('کارت ${row.number}'));
    expect(find.text('کارت PR-1405-0023'), findsOneWidget);
    expect(find.text('خرید تجهیزات ICU'), findsNothing);
  });

  testWidgets('outbox rows show the sync state and the retry button',
      (tester) async {
    final repo = _Repo([
      {
        'name': 'generic-request:x',
        'number': '—',
        'subject': 'ارسال نشده',
        'pending_sync': true,
        'status_key': 'submitted',
        'status_group': 'pending',
        'creation': DateTime.now().toIso8601String(),
      },
      {
        'name': 'generic-request:y',
        'number': '—',
        'subject': 'رد شده توسط سرور',
        'pending_sync': true,
        'status_key': 'failed',
        'status_label': 'نیازمند بررسی',
        'status_group': 'pending',
        'error': 'مانده مرخصی کافی نیست.',
        'creation': DateTime.now().toIso8601String(),
      },
    ]);
    await _open(tester, repo);
    expect(find.text('در انتظار همگام‌سازی'), findsOneWidget);
    expect(find.text('نیازمند بررسی'), findsOneWidget);
    expect(find.text('مانده مرخصی کافی نیست.'), findsOneWidget);
    await tester.tap(find.text('تلاش مجدد برای همگام‌سازی'));
    await tester.pumpAndSettle();
    expect(repo.syncs, 1);
  });

  testWidgets('pending requests are retried on the interval', (tester) async {
    final repo = _Repo(_fixtureRows())..hasPending = true;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(RequestListView(
        repository: repo,
        title: 't',
        retryInterval: const Duration(seconds: 5))));
    await tester.pumpAndSettle();
    final before = repo.queries.length;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(repo.queries.length, before + 1);
    repo.hasPending = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(repo.queries.length, before + 1, reason: 'nothing pending');
  });

  testWidgets('a tap opens the registered detail of the template and reloads',
      (tester) async {
    final repo = _Repo(_fixtureRows());
    RequestScreenRegistry.register(
        'purchase',
        RequestTemplateScreens(
            detail: (context, repository, name) =>
                Scaffold(appBar: AppBar(title: Text('جزئیات سفارشی $name')))));
    await _open(tester, repo);
    final before = repo.queries.length;
    await tester.tap(find.text('خرید تجهیزات ICU'));
    await tester.pumpAndSettle();
    expect(find.text('جزئیات سفارشی PR-1405-0023'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repo.queries.length, before + 1, reason: 'reloaded after return');
  });

  testWidgets('onOpen and the create buttons are wired', (tester) async {
    final repo = _Repo(_fixtureRows());
    final opened = <String>[];
    var created = 0;
    await _open(tester, repo,
        onOpen: (summary) async => opened.add(summary.name),
        onCreate: () => created++);
    await tester.tap(find.text('خرید تجهیزات ICU'));
    await tester.pumpAndSettle();
    expect(opened, ['PR-1405-0023']);
    await tester.tap(find.byTooltip('درخواست جدید'));
    expect(created, 1);

    await tester.pumpWidget(_app(RequestListView(
        repository: repo,
        title: 'x',
        onCreate: () => created++,
        createLabel: 'درخواست جدید')));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.text('درخواست جدید'));
    expect(created, 2);
  });

  testWidgets('renders at 320 without overflow', (tester) async {
    final repo = _Repo(_fixtureRows());
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        _app(RequestListView(repository: repo, title: 'درخواست‌های مرخصی')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
