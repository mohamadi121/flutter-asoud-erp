import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import 'workflow_instance_detail_page.dart';
import 'workflow_task_detail_page.dart';
import 'workflow_tasks_page.dart';
import '../../../directives/data/directive_repository.dart';
import '../../../directives/presentation/directive_pages.dart';
import '../../../directives/directive_navigation.dart';

/// Shared cartable route. The independent needs-action page remains unchanged.
class CartablePage extends StatefulWidget {
  const CartablePage({super.key, this.company = '', this.embedded = false});

  final String company;
  final bool embedded;

  @override
  State<CartablePage> createState() => _CartablePageState();
}

enum _Box { incoming, sent, inprogress, archive }

enum _Metric { open, action, overdue }

enum _Sort { newest, oldest, priority }

class _CartablePageState extends State<CartablePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<_Item> _items = [];
  List<String> _warnings = [];
  String? _error;
  String _name = '';
  bool _loading = true;
  bool _started = false;
  bool _partial = false;
  bool _canIssue = false;
  bool _filtersOpen = false;
  _Box _box = _Box.incoming;
  _Metric? _metric;
  _Sort _sort = _Sort.newest;
  String? _type;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    final warnings = <String>[];
    try {
      final repository = context.read<WorkflowTaskRepository>();
      final client = context.read<FrappeApiClient>();
      if (!client.isAuthenticated || repository.isOfflinePreview) {
        throw StateError('برای دریافت کارتابل واقعی به نشست آنلاین نیاز است.');
      }
      final user = await client.getCurrentUser();
      final groups = await Future.wait([
        for (final status in ['Open', 'Completed', 'Rejected', 'Cancelled'])
          repository.getMyTasks(status: status),
      ]);
      final sent = await repository.getMyInstances();
      final capped =
          groups.any((group) => group.length >= 200) || sent.length >= 200;
      var partial = capped;
      var canIssue = false;
      var directives = <Map<String, dynamic>>[];
      try {
        final api = ApiDirectiveRepository(client);
        directives = await api.list(widget.company);
        canIssue = (await api.options(widget.company))
            .allowedActions
            .contains('issue');
      } catch (_) {
        partial = true;
        warnings.add(
            'دستورات مدیر دریافت نشد؛ اتصال، مجوز سازمان یا استقرار سرویس دستورات را بررسی کنید.');
      }
      final tasks = <String, List<WorkflowTask>>{};
      for (final task in groups.expand((group) => group)) {
        final key = task.instance.isEmpty ? 'task:${task.id}' : task.instance;
        final bucket = tasks.putIfAbsent(key, () => []);
        if (!bucket.any((existing) => existing.id == task.id)) bucket.add(task);
      }
      final summaries = {for (final item in sent) item.id: item};
      // Task completion is not instance completion. Resolve the real lifecycle
      // for incoming records, with bounded concurrency rather than one burst.
      final missing = tasks.keys
          .where((id) => !summaries.containsKey(id) && !id.startsWith('task:'))
          .toList();
      var unavailable = 0;
      for (var offset = 0; offset < missing.length; offset += 6) {
        await Future.wait(missing.skip(offset).take(6).map((id) async {
          try {
            summaries[id] = (await repository.getInstance(id)).summary;
          } catch (_) {
            unavailable++;
          }
        }));
      }
      if (unavailable > 0) {
        warnings.add(
            'وضعیت گردش برخی دریافتی‌ها قابل دریافت نیست؛ آمار باز و در جریان ممکن است ناقص باشد.');
      }
      if (capped) {
        warnings.add(
            'سقف ۲۰۰ رکورد یکی از فهرست‌های سرور پر شده است. آمار فقط مربوط به داده‌های دریافت‌شده است، نه کل کارتابل.');
      }
      warnings.add(
          'گردش‌های عمومی فعلاً اطلاعات بایگانی و اولویت ندارند؛ مختومه‌شدن به‌معنی بایگانی نیست.');
      final sentIds = sent.map((item) => item.id).toSet();
      final ids = {...summaries.keys, ...tasks.keys};
      final items = [
        for (final id in ids)
          if (!directives.any((d) => d['workflow_instance'] == id))
            _Item.workflow(
                id, summaries[id], tasks[id] ?? [], sentIds.contains(id)),
        for (final directive in directives) _Item.directive(directive),
      ];
      if (!mounted) return;
      setState(() {
        _name = user.fullName.isNotEmpty ? user.fullName : user.userId;
        _items = items;
        _warnings = warnings;
        _partial = partial || unavailable > 0;
        _canIssue = canIssue;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // Do not retain possibly revoked records after an access/session error.
        _items = [];
        _name = '';
        _error = error is StateError
            ? error.message.toString()
            : failureMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _openPage(Widget page) async {
    final repository = context.read<WorkflowTaskRepository>();
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => RepositoryProvider<WorkflowTaskRepository>.value(
        value: repository,
        child: page,
      ),
    ));
    // Filters, selected tab, search and scroll controller survive navigation.
    if (mounted) await _load();
  }

  Future<void> _open(_Item item) async {
    if (item.directiveData != null) {
      return _openPage(
          DirectiveDetailPage(company: widget.company, id: item.id));
    }
    final tasks = item.tasks;
    if (_box == _Box.sent && item.summary != null) {
      return _openPage(WorkflowInstanceDetailPage(instance: item.id));
    }
    if (tasks.length == 1) {
      return _openPage(WorkflowTaskDetailPage(task: tasks.single.id));
    }
    if (tasks.length > 1) {
      final task = await showModalBottomSheet<WorkflowTask>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: ListView(children: [
                const ListTile(title: Text('اقدام‌ها و پیش‌نویس‌های این گردش')),
                for (final task in tasks)
                  ListTile(
                    title: Text(persianWorkflowStageTitle(task.title)),
                    subtitle: Text(
                        '${task.id} · ${persianWorkflowStatus(task.status)}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.pop(context, task),
                  ),
              ]),
            ),
          ),
        ),
      );
      if (task != null && mounted) {
        await _openPage(WorkflowTaskDetailPage(task: task.id));
      }
      return;
    }
    await _openPage(WorkflowInstanceDetailPage(instance: item.id));
  }

  List<_Item> get _visible {
    final query = _normalize(_search.text.trim());
    final rows = _items.where((item) {
      final inBox = switch (_box) {
        _Box.incoming => item.incoming && !item.archived,
        _Box.sent => item.sent && !item.archived,
        _Box.inprogress => item.open && !item.archived,
        _Box.archive => item.archived,
      };
      return inBox &&
          (_metric == null || item.matches(_metric!)) &&
          (_type == null || item.type == _type) &&
          (query.isEmpty ||
              _normalize(
                      '${item.id} ${item.title} ${item.type} ${item.sender} ${item.recipients}')
                  .contains(query));
    }).toList();
    rows.sort((a, b) {
      if (_sort == _Sort.priority && a.priority != b.priority) {
        return (b.priority ?? -1).compareTo(a.priority ?? -1);
      }
      // Missing dates remain last in either direction.
      if (a.date == null && b.date != null) return 1;
      if (b.date == null && a.date != null) return -1;
      final dateOrder = a.date == null ? 0 : a.date!.compareTo(b.date!);
      final order = _sort == _Sort.oldest ? dateOrder : -dateOrder;
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return rows;
  }

  void _clearFilters() => setState(() {
        _search.clear();
        _type = null;
        _metric = null;
        _sort = _Sort.newest;
      });

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AsoudColors.background,
        bottomNavigationBar: widget.embedded
            ? null
            : DirectiveBottomBar(company: widget.company),
        appBar: AsoudHeader(
          title: 'کارتابل من',
          subtitle: _name.isEmpty ? 'کارتابل سازمانی' : _name,
          action: IconButton(
            tooltip: 'تازه‌سازی',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: AsoudColors.primary),
          ),
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              if (!_loading) await _load();
            },
            child: CustomScrollView(
              key: const PageStorageKey('unified-cartable'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverList.list(children: [
                    if (_loading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _metricCard(_Metric.open, 'موارد باز',
                              Icons.folder_open, AsoudColors.primary),
                          const SizedBox(width: 6),
                          _metricCard(_Metric.action, 'نیازمند اقدام',
                              Icons.pending_actions, AsoudColors.warning),
                          const SizedBox(width: 6),
                          _metricCard(_Metric.overdue, 'معوق', Icons.schedule,
                              AsoudColors.danger),
                        ]),
                    const SizedBox(height: 6),
                    Text(
                        _partial
                            ? 'آمار داده‌های دریافت‌شده · مستقل از تب و فیلتر'
                            : 'آمار موارد مرتبط دریافت‌شده · مستقل از تب و فیلتر',
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                    const SizedBox(height: 12),
                    _tabs(),
                    if (_canIssue)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FilledButton.icon(
                              onPressed: () => _openPage(
                                  DirectiveCreatePage(company: widget.company)),
                              icon: const Icon(Icons.add),
                              label: const Text('دستور جدید'))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'جست‌وجوی کارتابل',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'پاک کردن جست‌وجو',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(_search.clear),
                                ),
                          filled: true,
                          fillColor: AsoudColors.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      )),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: _filtersOpen
                            ? 'بستن فیلترها'
                            : 'نوع سند و مرتب‌سازی',
                        isSelected: _filtersOpen ||
                            _type != null ||
                            _sort != _Sort.newest,
                        onPressed: () =>
                            setState(() => _filtersOpen = !_filtersOpen),
                        icon: const Icon(Icons.tune),
                      ),
                    ]),
                    if (_filtersOpen) _filterPanel(),
                    if (_metric != null ||
                        _type != null ||
                        _search.text.isNotEmpty ||
                        _sort != _Sort.newest)
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off_outlined,
                                  size: 18),
                              label: const Text('پاک کردن فیلترهای فعال'))),
                    TextButton.icon(
                      onPressed: () => _openPage(const WorkflowTasksPage()),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('نیازمند اقدام من و ادامه پیش‌نویس‌ها'),
                    ),
                    if (_error != null) _notice(_error!, error: true),
                    if (_error == null && !_loading)
                      for (final warning in _warnings) _notice(warning),
                    if (!_loading && _error == null && visible.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(children: [
                            const Icon(Icons.inbox_outlined,
                                size: 48, color: AsoudColors.muted),
                            const SizedBox(height: 12),
                            Text(_box == _Box.archive
                                ? 'مورد بایگانی‌شده‌ای دریافت نشد'
                                : 'موردی با این شرایط پیدا نشد'),
                            const SizedBox(height: 6),
                            const Text('تب یا فیلترها را تغییر دهید.',
                                style: TextStyle(color: AsoudColors.muted)),
                          ])),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) => _card(visible[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard(_Metric metric, String label, IconData icon, Color color) {
    final selected = _metric == metric;
    final count = _items.where((item) => item.matches(metric)).length;
    return Expanded(
        child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: color.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected ? color : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _metric = selected ? null : metric),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(height: 5),
                Text(_loading || _error != null ? '—' : toPersianDigits(count),
                    style: TextStyle(
                        color: color,
                        fontSize: 23,
                        fontWeight: FontWeight.w900)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 11)),
              ])),
        ),
      ),
    ));
  }

  Widget _tabs() {
    const tabs = [
      (_Box.incoming, 'دریافتی', Icons.move_to_inbox_outlined),
      (_Box.sent, 'ارسالی', Icons.outbox_outlined),
      (_Box.inprogress, 'در جریان', Icons.autorenew),
      (_Box.archive, 'بایگانی', Icons.archive_outlined),
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final tab in tabs)
        Expanded(
            child: Semantics(
          selected: _box == tab.$1,
          button: true,
          child: Material(
            color: _box == tab.$1
                ? AsoudColors.primary.withValues(alpha: .09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _box = tab.$1),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  child: Column(children: [
                    Icon(tab.$3,
                        color: _box == tab.$1
                            ? AsoudColors.primary
                            : AsoudColors.muted),
                    const SizedBox(height: 6),
                    Text(tab.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: _box == tab.$1
                                ? AsoudColors.primary
                                : AsoudColors.muted)),
                  ])),
            ),
          ),
        )),
    ]);
  }

  Widget _filterPanel() {
    final types = _items.map((item) => item.type).toSet().toList()..sort();
    if (_type != null && !types.contains(_type)) types.add(_type!);
    return Card(
        margin: const EdgeInsets.only(top: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _type ?? '',
              key: ValueKey('type:$_type'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع سند'),
              items: [
                const DropdownMenuItem(value: '', child: Text('تمام انواع')),
                for (final type in types)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  setState(() => _type = value == '' ? null : value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_Sort>(
              initialValue: _sort,
              key: ValueKey(_sort),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'مرتب‌سازی'),
              items: const [
                DropdownMenuItem(
                    value: _Sort.newest, child: Text('جدیدترین ابتدا')),
                DropdownMenuItem(
                    value: _Sort.oldest, child: Text('قدیمی‌ترین ابتدا')),
                DropdownMenuItem(
                    value: _Sort.priority, child: Text('اولویت بالاتر ابتدا')),
              ],
              onChanged: (value) =>
                  setState(() => _sort = value ?? _Sort.newest),
            ),
            if (_sort == _Sort.priority)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'موارد بدون اولویت در انتها، بر اساس تاریخ نمایش داده می‌شوند.',
                      style:
                          TextStyle(fontSize: 11, color: AsoudColors.muted))),
            Wrap(alignment: WrapAlignment.end, children: [
              TextButton(
                  onPressed: _clearFilters, child: const Text('پاک کردن')),
              TextButton(
                  onPressed: () => setState(() => _filtersOpen = false),
                  child: const Text('اعمال و بستن')),
            ]),
          ]),
        ));
  }

  Widget _notice(String message, {bool error = false}) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? AsoudColors.dangerSurface : AsoudColors.warningSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message,
              style: TextStyle(
                  fontSize: 11,
                  color: error ? AsoudColors.danger : AsoudColors.warning)),
          if (error)
            TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('تلاش مجدد')),
        ]),
      );

  Widget _card(_Item item) => Card(
        key: ValueKey(item.id),
        margin: const EdgeInsets.only(bottom: 10),
        color: AsoudColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AsoudColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(item),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const AsoudIconBox(
                        icon: Icons.description_outlined,
                        color: AsoudColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.type,
                              style: const TextStyle(
                                  fontSize: 11, color: AsoudColors.primary)),
                          Text(item.id,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontSize: 10, color: AsoudColors.muted)),
                        ])),
                  ]),
                  const SizedBox(height: 10),
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AsoudColors.text)),
                  const SizedBox(height: 8),
                  Text('وضعیت: ${item.status}',
                      style: const TextStyle(fontSize: 12)),
                  if (_box == _Box.sent && item.recipients.isNotEmpty)
                    Text('مسئول فعلی: ${item.recipients}',
                        style: const TextStyle(fontSize: 11)),
                  if (_box != _Box.sent && item.sender.isNotEmpty)
                    Text('فرستنده: ${item.sender}',
                        style: const TextStyle(fontSize: 11)),
                  if (item.date != null) _dateLine('تاریخ', item.date!),
                  if (item.due != null) _dateLine('سررسید', item.due!),
                  if (item.overdue)
                    const Text('مهلت انجام گذشته است',
                        style: TextStyle(
                            color: AsoudColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('مشاهده جزئیات',
                            style: TextStyle(color: AsoudColors.primary)),
                        Icon(Icons.chevron_left, color: AsoudColors.primary),
                      ]),
                ],
              )),
        ),
      );

  Widget _dateLine(String label, DateTime date) => Text(
        '$label: ${formatJalaliDateTimeIso(date.toLocal().toIso8601String())}',
        style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
      );
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('\u200c', ' ');

/// One row per workflow instance, never one row per task plus its instance.
class _Item {
  _Item.directive(Map<String, dynamic> data)
      : id = data['id'] as String,
        summary = null,
        tasks = [],
        sent = data['sent'] == true,
        directiveData = data;
  _Item.workflow(this.id, this.summary, List<WorkflowTask> tasks, this.sent)
      : directiveData = null,
        tasks = [...tasks]..sort((a, b) {
            if (a.status == 'Open' && b.status != 'Open') return -1;
            if (b.status == 'Open' && a.status != 'Open') return 1;
            return (b.assignedOn ?? DateTime(1970))
                .compareTo(a.assignedOn ?? DateTime(1970));
          });

  final String id;
  final Map<String, dynamic>? directiveData;
  final WorkflowInstanceSummary? summary;
  final List<WorkflowTask> tasks;
  final bool sent;
  bool get incoming => directiveData?['incoming'] as bool? ?? tasks.isNotEmpty;
  bool get archived => directiveData?['archived'] == true;
  bool get action =>
      directiveData?['needs_action'] as bool? ??
      tasks.any((task) => task.status == 'Open');
  bool get open =>
      directiveData?['open'] as bool? ??
      (summary != null ? summary!.status == 'Running' : action);
  bool get overdue =>
      directiveData?['overdue'] as bool? ??
      (open &&
          tasks.any((task) =>
              task.status == 'Open' &&
              task.dueOn != null &&
              task.dueOn!.isBefore(DateTime.now())));
  String get title =>
      directiveData?['subject'] as String? ??
      (summary?.subject.isNotEmpty == true
          ? summary!.subject
          : tasks.isNotEmpty
              ? persianWorkflowStageTitle(tasks.first.title)
              : id);
  String get type => directiveData != null
      ? 'دستورات مدیر'
      : summary?.referenceDoctype.isNotEmpty == true
          ? summary!.referenceDoctype
          : 'گردش کار';
  String get status => directiveData != null
      ? directiveLabel(directiveData!['status'] as String)
      : summary == null
          ? 'وضعیت گردش دریافت نشده'
          : persianWorkflowStatus(summary!.status);
  String get sender => directiveData?['sender'] as String? ?? '';
  String get recipients => directiveData != null
      ? directiveRows(directiveData!['executors'])
          .map((e) => directiveMap(e['person'])['name'])
          .join('، ')
      : summary?.currentAssignees.join('، ') ?? '';
  int? get priority =>
      const {'Medium': 0, 'High': 1, 'Urgent': 2}[directiveData?['priority']];
  DateTime? get date => directiveData != null
      ? DateTime.tryParse(directiveData!['creation'] as String)
      : summary?.startedOn ?? (tasks.isEmpty ? null : tasks.first.assignedOn);
  DateTime? get due {
    if (directiveData != null) {
      return DateTime.tryParse(directiveData!['due_date'] as String? ?? '');
    }
    final dates = tasks
        .where((task) => task.status == 'Open' && task.dueOn != null)
        .map((task) => task.dueOn!)
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  bool matches(_Metric metric) => switch (metric) {
        _Metric.open => open,
        _Metric.action => action,
        _Metric.overdue => overdue,
      };
}
