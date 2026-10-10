import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/dashboard_summary_repository.dart';
import '../../data/demo/dashboard_demo_data.dart';

/// Home KPI cards. While previewing it keeps the demo figures; with a real
/// session it reads `get_home_summary` and hides any figure the server returns
/// as `null` (the user may not read that DocType) instead of a false zero.
class HomeMetricsSection extends StatefulWidget {
  const HomeMetricsSection({
    this.company,
    this.offlinePreview = false,
    super.key,
  });

  final String? company;
  final bool offlinePreview;

  @override
  State<HomeMetricsSection> createState() => _HomeMetricsSectionState();
}

class _HomeMetricsSectionState extends State<HomeMetricsSection> {
  Future<HomeSummary>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final company = widget.company?.trim() ?? '';
    if (widget.offlinePreview || company.isEmpty) return;
    final client = _maybeClient();
    if (client == null) return;
    _future = DashboardSummaryRepository(client).loadHome(company);
  }

  FrappeApiClient? _maybeClient() {
    try {
      return context.read<FrappeApiClient>();
    } catch (_) {
      // A page without the shared client renders the home figures only when a
      // session exists; without it the section is simply not shown.
      return null;
    }
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    if (widget.offlinePreview) {
      return _MetricsGrid(demo: true, metrics: _demoHomeMetrics());
    }
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<HomeSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MetricsLoading();
        }
        if (snapshot.hasError) {
          // Only a real API failure becomes a visible error with a retry; an
          // unexpected local error leaves the dashboard as it was.
          if (snapshot.error is! ApiException) return const SizedBox.shrink();
          return _MetricsError(failure: snapshot.error, onRetry: _reload);
        }
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();
        final currency = summary.currency;
        final metrics = <_Metric>[
          if (summary.todayReceipts != null)
            _Metric('دریافتی امروز', Icons.payments_outlined,
                AsoudColors.success, _money(summary.todayReceipts!, currency),
                hint: 'امروز'),
          if (summary.todaySales != null)
            _Metric('فروش امروز', Icons.bar_chart_rounded, AsoudColors.primary,
                _money(summary.todaySales!, currency),
                hint: 'امروز'),
          if (summary.bankAndCash?.total != null)
            _Metric('موجودی بانک', Icons.account_balance_outlined,
                AsoudColors.purple,
                _money(summary.bankAndCash!.total!, currency),
                hint: _bankHint(summary.bankAndCash!)),
          if (summary.openDocuments?.total != null)
            _Metric('اسناد باز', Icons.description_outlined,
                AsoudColors.warning,
                formatCount(summary.openDocuments!.total, 'سند'),
                hint: 'نیازمند پیگیری'),
        ];
        if (metrics.isEmpty) return const SizedBox.shrink();
        return _MetricsGrid(metrics: metrics);
      },
    );
  }
}

/// Settings «خلاصه وضعیت سیستم» block. Previewing shows the demo figures;
/// a signed-in user reads `get_system_summary` (System Manager only), so a
/// refused read shows the no-access message without a retry button.
class SystemSummarySection extends StatefulWidget {
  const SystemSummarySection({
    this.offlinePreview = false,
    this.onOpenTasks,
    this.onOpenSync,
    super.key,
  });

  final bool offlinePreview;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenSync;

  @override
  State<SystemSummarySection> createState() => _SystemSummarySectionState();
}

class _SystemSummarySectionState extends State<SystemSummarySection> {
  Future<SystemSummary>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (widget.offlinePreview) return;
    final client = _maybeClient();
    if (client == null) return;
    _future = DashboardSummaryRepository(client).loadSystem();
  }

  FrappeApiClient? _maybeClient() {
    try {
      return context.read<FrappeApiClient>();
    } catch (_) {
      return null;
    }
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    if (widget.offlinePreview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          _ResponsiveMetricsGrid(
            metrics: _demoSystemMetrics(
                onOpenTasks: widget.onOpenTasks,
                onOpenSync: widget.onOpenSync),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'آمار نمایشی برای پیش‌نمایش آفلاین است و روی سرور ذخیره نمی‌شود.',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
          ),
        ],
      );
    }
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<SystemSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _live(_header(), const _MetricsLoading());
        }
        if (snapshot.hasError) {
          if (snapshot.error is! ApiException) return const SizedBox.shrink();
          return _live(
              _header(), _MetricsError(failure: snapshot.error, onRetry: _reload));
        }
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();
        final metrics = _systemMetrics(summary,
            onOpenTasks: widget.onOpenTasks, onOpenSync: widget.onOpenSync);
        if (metrics.isEmpty) return const SizedBox.shrink();
        return _live(_header(), _ResponsiveMetricsGrid(metrics: metrics));
      },
    );
  }

  Widget _header() => const Text('خلاصه وضعیت سیستم',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900));

  Widget _live(Widget header, Widget body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const SizedBox(height: 10), body],
      );
}

class _ResponsiveMetricsGrid extends StatelessWidget {
  const _ResponsiveMetricsGrid({required this.metrics});
  final List<_Metric> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => _MetricsGrid(
          columns: constraints.maxWidth < 300 ? 2 : 3,
          metrics: metrics,
        ),
      );
}

class _Metric {
  const _Metric(this.title, this.icon, this.color, this.value, {this.hint, this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String? hint;
  final VoidCallback? onTap;
}

const _demoHomeIcons = <String, (IconData, Color)>{
  'دریافتی امروز': (Icons.payments_outlined, AsoudColors.success),
  'فروش امروز': (Icons.bar_chart_rounded, AsoudColors.primary),
  'موجودی بانک': (Icons.account_balance_outlined, AsoudColors.purple),
  'اسناد باز': (Icons.description_outlined, AsoudColors.warning),
};

List<_Metric> _demoHomeMetrics() => demoDashboardMetrics().map((m) {
      final style = _demoHomeIcons[m.title] ??
          (Icons.insights_outlined, AsoudColors.primary);
      return _Metric(m.title, style.$1, style.$2, m.value, hint: m.hint);
    }).toList();

List<_Metric> _demoSystemMetrics(
        {VoidCallback? onOpenTasks, VoidCallback? onOpenSync}) =>
    [
      _demoMetric('کاربران فعال', Icons.people_outline, AsoudColors.primary),
      _demoMetric('کاربران آنلاین', Icons.desktop_windows_outlined,
          AsoudColors.success),
      _demoMetric('فضای ذخیره‌سازی', Icons.storage_outlined, AsoudColors.primary),
      _demoMetric('درخواست‌های در انتظار', Icons.pending_actions,
          AsoudColors.warning,
          onTap: onOpenTasks),
      _demoMetric('خطاهای سیستم', Icons.bug_report_outlined, AsoudColors.purple),
      _demoMetric('وضعیت همگام‌سازی', Icons.sync, AsoudColors.success,
          onTap: onOpenSync),
    ];

_Metric _demoMetric(String title, IconData icon, Color color,
        {VoidCallback? onTap}) =>
    _Metric(
      title,
      icon,
      color,
      demoSystemStatus(title),
      hint: 'نمایشی',
      onTap: onTap,
    );

List<_Metric> _systemMetrics(SystemSummary summary,
        {VoidCallback? onOpenTasks, VoidCallback? onOpenSync}) =>
    [
      if (summary.usersActive != null)
        _Metric('کاربران فعال', Icons.people_outline, AsoudColors.primary,
            formatCount(summary.usersActive),
            hint: summary.usersTotal == null
                ? 'کاربر سیستم'
                : 'از ${formatCount(summary.usersTotal)} کاربر'),
      if (summary.usersOnline != null)
        _Metric(
            'کاربران آنلاین',
            Icons.desktop_windows_outlined,
            AsoudColors.success,
            formatCount(summary.usersOnline),
            hint: summary.onlineWindowMinutes == null
                ? 'هنگام بررسی'
                : '${formatCount(summary.onlineWindowMinutes, 'دقیقه')} اخیر'),
      if (_storageValue(summary) != null)
        _Metric('فضای ذخیره‌سازی', Icons.storage_outlined, AsoudColors.primary,
            _storageValue(summary)!,
            hint: _storageHint(summary)),
      if (summary.pendingWorkflowTasks != null)
        _Metric('درخواست‌های در انتظار', Icons.pending_actions,
            AsoudColors.warning, formatCount(summary.pendingWorkflowTasks),
            hint: 'گردش‌کار باز', onTap: onOpenTasks),
      if (summary.errorsLast24h != null)
        _Metric('خطاهای سیستم', Icons.bug_report_outlined, AsoudColors.purple,
            formatCount(summary.errorsLast24h),
            hint: '۲۴ ساعت اخیر'),
      if (_syncValue(summary) != null)
        _Metric('وضعیت همگام‌سازی', Icons.sync, AsoudColors.success,
            _syncValue(summary)!,
            hint: summary.syncLastCompletedOn == null
                ? 'موردی ثبت نشده'
                : 'آخرین: ${formatDateJalali(summary.syncLastCompletedOn)}',
            onTap: onOpenSync),
    ];

String? _storageValue(SystemSummary summary) {
  final used = summary.storageUsedBytes;
  final quota = summary.storageQuotaBytes;
  if (quota != null && quota > 0 && used != null) {
    return '${formatNumber(((used / quota) * 100).round())}٪';
  }
  if (used != null) return _formatBytes(used);
  return null;
}

String? _storageHint(SystemSummary summary) {
  final quota = summary.storageQuotaBytes;
  if (quota == null || quota <= 0) return 'بدون سقف تعیین‌شده';
  return 'از ${_formatBytes(quota)}';
}

String? _syncValue(SystemSummary summary) {
  final stuck = summary.syncStuckRequests;
  if (stuck != null && stuck > 0) return 'نیازمند بررسی';
  if (summary.syncLastCompletedOn != null) return 'سالم';
  return 'بدون سابقه';
}

String _formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    return '${formatNumber((bytes / gb).toStringAsFixed(1))} گیگابایت';
  }
  if (bytes >= mb) return '${formatNumber((bytes / mb).round())} مگابایت';
  return '${formatNumber(bytes)} بایت';
}

String _money(num amount, String? currency) {
  final formatted = formatNumber(amount);
  if (currency == null || currency.isEmpty) return formatted;
  final unit = currency == 'Toman' ? 'تومان' : 'ریال';
  return '$formatted $unit';
}

String _bankHint(BankAndCash bank) => bank.accountCount > 0
    ? formatCount(bank.accountCount, 'حساب بانکی')
    : 'خزانه';

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics, this.demo = false, this.columns = 2});
  final List<_Metric> metrics;
  final bool demo;
  final int columns;
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: demo ? 140 : 126,
        children: metrics.map(_MetricCard.new).toList(),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);
  final _Metric metric;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: metric.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(metric.title,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700))),
                  AsoudIconBox(icon: metric.icon, color: metric.color, size: 30),
                ]),
                Text(metric.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: metric.value.length > 18 ? 15 : 18,
                        fontWeight: FontWeight.w900)),
                Text(metric.hint ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 8, color: AsoudColors.muted)),
              ],
            ),
          ),
        ),
      );
}

class _MetricsLoading extends StatelessWidget {
  const _MetricsLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _MetricsError extends StatelessWidget {
  const _MetricsError({required this.failure, required this.onRetry});
  final Object? failure;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 240,
        child: ErrorState(failure: failure ?? 'خطای نامشخص', onRetry: onRetry),
      );
}
