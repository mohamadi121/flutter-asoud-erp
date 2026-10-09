import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';
import '../pages/request_flow_pages.dart';
import '../request_screen_registry.dart';

/// Persian labels of the request priorities.
const requestPriorityLabels = {
  'Normal': 'عادی',
  'High': 'مهم',
  'Urgent': 'فوری',
};

/// The tabs of a request list: `status_group` and its label.
const requestListTabs = [
  ('all', 'همه'),
  ('pending', 'در انتظار بررسی'),
  ('approved', 'تأیید شده'),
  ('rejected', 'رد شده'),
];

/// The signed-in user's own requests (§6.4): search (debounced), a filter
/// sheet (priority, date range), the tabs «همه / در انتظار بررسی / تأیید شده /
/// رد شده» with the server's counts, pull-to-refresh and pagination (20 a
/// page). Requests waiting in the outbox come first. Empty and error states
/// have a retry. A full page (header, body).
class RequestListView extends StatefulWidget {
  const RequestListView({
    required this.repository,
    required this.title,
    this.templateKey,
    this.subtitle,
    this.cardBuilder,
    this.emptyText = 'هنوز درخواستی ثبت نشده است.',
    this.searchHint = 'جستجو در درخواست‌ها ...',
    this.onCreate,
    this.createLabel,
    this.onOpen,
    this.header,
    this.pageSize = 20,
    this.searchDebounce = const Duration(milliseconds: 400),
    this.retryInterval = const Duration(seconds: 20),
    super.key,
  });

  final GenericRequestRepository repository;
  final String title;
  final String? subtitle;

  /// Limits the list to one template (`template_key`); null lists everything.
  final String? templateKey;

  /// Builds a card; the default is [RequestListCard]. Wrap the card in an
  /// `InkWell`/`Card` with `onTap` yourself, or use the default.
  final Widget Function(BuildContext context, RequestSummary summary)?
      cardBuilder;
  final String emptyText, searchHint;

  /// Adds the «+» button of the header, or an extended floating button
  /// labelled [createLabel] when that is given.
  final VoidCallback? onCreate;
  final String? createLabel;

  /// Opens a request; the default shows the registered detail page of its
  /// template (or the generic one) and reloads afterwards.
  final Future<void> Function(RequestSummary summary)? onOpen;

  /// Shown above the search box (e.g. a template filter).
  final Widget? header;
  final int pageSize;
  final Duration searchDebounce, retryInterval;

  @override
  State<RequestListView> createState() => RequestListViewState();
}

class RequestListViewState extends State<RequestListView> {
  final _scroll = ScrollController();
  final _searchBox = TextEditingController();
  Timer? _debounce, _retryTimer;
  String _tab = 'all', _search = '';
  String? _priority, _dateFrom, _dateTo;
  List<RequestSummary> _items = const [];
  int _total = 0, _local = 0;
  Map<String, int> _counts = const {};
  bool _loading = true, _loadingMore = false, _retrying = false;
  Object? _error;
  int _token = 0;

  bool get _filtered =>
      _priority != null || _dateFrom != null || _dateTo != null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 240 &&
          _hasMore &&
          !_loading &&
          !_loadingMore) {
        loadMore();
      }
    });
    _retryTimer = Timer.periodic(widget.retryInterval, (_) async {
      if (_retrying || !mounted) return;
      _retrying = true;
      try {
        if ((await widget.repository.pending()).isNotEmpty) await reload();
      } catch (_) {
        // The pending requests stay on the device; the next tick retries.
      } finally {
        _retrying = false;
      }
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant RequestListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateKey != widget.templateKey) reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _retryTimer?.cancel();
    _scroll.dispose();
    _searchBox.dispose();
    super.dispose();
  }

  bool get _hasMore => _items.length < _total;

  Future<void> _load({bool keepItems = false}) async {
    final token = ++_token;
    if (!keepItems) setState(() => _loading = true);
    try {
      final page = await widget.repository.listPage(
        templateKey: widget.templateKey,
        statusGroup: _tab,
        search: _search,
        limit: widget.pageSize,
        priority: _priority,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted || token != _token) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _local = page.localCount;
        _counts = page.counts;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// Loads the first page again (after an edit, a retry or pull-to-refresh).
  Future<void> reload() => _load(keepItems: _items.isNotEmpty);

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final token = _token;
    setState(() => _loadingMore = true);
    try {
      final stored = _items.length - _local;
      final page = await widget.repository.listPage(
        templateKey: widget.templateKey,
        statusGroup: _tab,
        search: _search,
        offset: stored,
        limit: widget.pageSize,
        priority: _priority,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted || token != _token) return;
      setState(() {
        _items = [..._items, ...page.items];
        _total = page.total + _local;
        _counts = page.counts.isEmpty ? _counts : page.counts;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دریافت ادامه فهرست ممکن نشد.')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDebounce, () {
      if (!mounted || text.trim() == _search) return;
      _search = text.trim();
      _load();
    });
  }

  void _setTab(String tab) {
    if (tab == _tab) return;
    _tab = tab;
    _load();
  }

  Future<void> _filter() async {
    final result = await showModalBottomSheet<_Filter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: _FilterSheet(initial: _Filter(_priority, _dateFrom, _dateTo))),
    );
    if (result == null || !mounted) return;
    _priority = result.priority;
    _dateFrom = result.dateFrom;
    _dateTo = result.dateTo;
    await _load();
  }

  Future<void> _open(RequestSummary summary) async {
    if (widget.onOpen != null) {
      await widget.onOpen!(summary);
    } else {
      await RequestScreenRegistry.openDetail(
          context, widget.repository, summary.name,
          templateKey: summary.templateKey);
    }
    if (mounted) await reload();
  }

  Future<void> _retryNow() async {
    try {
      await widget.repository.sync(retry: true);
      await reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('اتصال برقرار نشد؛ داده‌ها محفوظ‌اند.')));
      }
    }
  }

  Widget _tabs() => Row(children: [
        for (final (group, label) in requestListTabs)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                key: ValueKey('request-tab:$group'),
                onTap: () => _setTab(group),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  decoration: BoxDecoration(
                    color: _tab == group
                        ? AsoudColors.primary
                        : AsoudColors.surface,
                    border: Border.all(
                        color: _tab == group
                            ? AsoudColors.primary
                            : AsoudColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _tab == group
                                ? Colors.white
                                : AsoudColors.text)),
                    if (_counts.containsKey(group))
                      Text(toPersianDigits(_counts[group]!),
                          style: TextStyle(
                              fontSize: 10,
                              color: _tab == group
                                  ? Colors.white70
                                  : AsoudColors.muted)),
                  ]),
                ),
              ),
            ),
          ),
      ]);

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(children: [
          TextField(
            controller: _searchBox,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'فیلتر',
                onPressed: _filter,
                icon: Badge(
                    isLabelVisible: _filtered,
                    smallSize: 8,
                    child: const Icon(Icons.filter_alt_outlined)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _tabs(),
        ]),
      );

  Widget _state(IconData icon, String text,
          {String? action, VoidCallback? onAction}) =>
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(icon, size: 44, color: AsoudColors.muted),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AsoudColors.muted)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final hasPending = _items.any((row) => row.pendingSync);
    final searching = _search.isNotEmpty || _filtered || _tab != 'all';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: widget.title,
          subtitle: widget.subtitle,
          action: widget.onCreate == null || widget.createLabel != null
              ? null
              : IconButton.filled(
                  tooltip: 'درخواست جدید',
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add_rounded)),
        ),
        floatingActionButton:
            widget.onCreate != null && widget.createLabel != null
                ? FloatingActionButton.extended(
                    icon: const Icon(Icons.add),
                    label: Text(widget.createLabel!),
                    onPressed: widget.onCreate)
                : null,
        body: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (widget.header != null)
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: widget.header),
              _controls(),
              if (hasPending)
                TextButton(
                    onPressed: _retryNow,
                    child: const Text('تلاش مجدد برای همگام‌سازی')),
              if (_loading && _items.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null && _items.isEmpty)
                _state(
                    Icons.cloud_off_rounded,
                    _error is ApiException
                        ? (_error as ApiException).message
                        : 'دریافت فهرست ممکن نشد.',
                    action: 'دریافت ناموفق؛ تلاش دوباره',
                    onAction: () => _load())
              else if (_items.isEmpty)
                _state(
                    searching ? Icons.search_off_rounded : Icons.inbox_outlined,
                    searching
                        ? 'موردی با این جستجو یا فیلتر پیدا نشد.'
                        : widget.emptyText)
              else ...[
                for (final summary in _items)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: widget.cardBuilder != null
                        ? InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _open(summary),
                            child: widget.cardBuilder!(context, summary))
                        : RequestListCard(
                            summary: summary, onTap: () => _open(summary)),
                  ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                        onPressed: _loadingMore ? null : loadMore,
                        child: _loadingMore
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('نمایش بیشتر')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The default list card: status chip and number, subject, requester, date,
/// item and attachment counts.
class RequestListCard extends StatelessWidget {
  const RequestListCard({required this.summary, this.onTap, super.key});
  final RequestSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final error = '${summary.raw['error'] ?? ''}';
    Widget meta(IconData icon, String text) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AsoudColors.muted),
          const SizedBox(width: 4),
          Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted))),
        ]);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Flexible(child: RequestStatusChip(summary.raw)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(summary.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.muted))),
            ]),
            const SizedBox(height: 8),
            Text(summary.subject,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            if (summary.requestType.isNotEmpty && summary.templateKey.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(summary.requestType,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.muted))),
            if (summary.requesterName.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: meta(
                      Icons.person_outline_rounded, summary.requesterName)),
            const SizedBox(height: 6),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if (summary.creation.isNotEmpty)
                meta(Icons.calendar_today_outlined,
                    formatJalaliIso(summary.creation)),
              if (summary.itemCount > 0)
                meta(Icons.inventory_2_outlined,
                    '${toPersianDigits(summary.itemCount)} قلم'),
              if (summary.attachmentCount > 0)
                meta(Icons.attach_file_rounded,
                    toPersianDigits(summary.attachmentCount)),
            ]),
            if (summary.pendingSync && error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(error,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.danger))),
          ]),
        ),
      ),
    );
  }
}

class _Filter {
  const _Filter(this.priority, this.dateFrom, this.dateTo);
  final String? priority, dateFrom, dateTo;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _Filter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? priority = widget.initial.priority;
  late final from = TextEditingController(text: widget.initial.dateFrom ?? '');
  late final to = TextEditingController(text: widget.initial.dateTo ?? '');

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  String? _iso(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty || asoudDateValidator(text) != null ? null : text;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('فیلتر درخواست‌ها',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            const Text('اولویت',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              ChoiceChip(
                  label: const Text('همه'),
                  selected: priority == null,
                  onSelected: (_) => setState(() => priority = null)),
              for (final entry in requestPriorityLabels.entries)
                ChoiceChip(
                    label: Text(entry.value),
                    selected: priority == entry.key,
                    onSelected: (_) => setState(() => priority = entry.key)),
            ]),
            const SizedBox(height: 14),
            AsoudFormDateField(
                controller: from, label: 'از تاریخ', clearable: true),
            AsoudFormDateField(
                controller: to, label: 'تا تاریخ', clearable: true),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                          context, const _Filter(null, null, null)),
                      child: const Text('حذف فیلتر'))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(
                          context, _Filter(priority, _iso(from), _iso(to))),
                      child: const Text('اعمال فیلتر'))),
            ]),
          ]),
        ),
      );
}
