import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../cubit/workflow_list_cubit.dart';
import 'workflow_form_page.dart';

class WorkflowListPage extends StatelessWidget {
  const WorkflowListPage({this.company, this.onCreate, super.key});

  final String? company;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkflowListCubit(
          repository: context.read<WorkflowRepository>(),
          company: company,
        )..load(),
        child: _WorkflowListView(onCreate: onCreate),
      );
}

class _WorkflowListView extends StatelessWidget {
  const _WorkflowListView({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const _Header(),
            const _SearchAndFilter(),
            const _StatusTabs(),
            BlocSelector<WorkflowListCubit, WorkflowListState, bool>(
              selector: (state) => state.offlinePreview,
              builder: (_, offline) => offline
                  ? const AsoudOfflinePreviewBanner()
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: BlocBuilder<WorkflowListCubit, WorkflowListState>(
                builder: (context, state) {
                  if (state.status == WorkflowListLoadStatus.loading &&
                      state.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == WorkflowListLoadStatus.failure &&
                      state.items.isEmpty) {
                    return _FailureState(
                        message: state.message ?? 'خطای نامشخص');
                  }
                  if (state.items.isEmpty) return const _EmptyState();
                  return RefreshIndicator(
                    onRefresh: context.read<WorkflowListCubit>().load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 9, 16, 16),
                      children: [
                        Row(children: [
                          Text('مرتب‌سازی: ${_orderLabel(state.orderBy)}',
                              style: const TextStyle(
                                  fontSize: 9, color: AsoudColors.muted)),
                          const Spacer(),
                          Text('تعداد کل: ${state.items.length}',
                              style: const TextStyle(
                                  fontSize: 9, color: AsoudColors.muted)),
                        ]),
                        const SizedBox(height: 8),
                        for (final item in state.items)
                          _WorkflowCard(item: item),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 64),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width - 32,
            height: 50,
            child: FilledButton.icon(
              onPressed: onCreate ??
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const WorkflowFormPage(),
                      )),
              icon: const Icon(Icons.add_rounded),
              label: const Text('ایجاد گردش‌کار جدید'),
            ),
          ),
        ),
        bottomNavigationBar: const _WorkflowBottomNavigation(),
      );
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 8),
        child: Row(children: [
          IconButton(
            tooltip: 'اعلان‌ها',
            onPressed: () {},
            icon: const Badge(child: Icon(Icons.notifications_none_rounded)),
          ),
          const Expanded(
            child: Text('گردش‌کارها',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const AsoudIconBox(
            icon: Icons.hub_rounded,
            color: AsoudColors.primary,
            size: 38,
          ),
        ]),
      );
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          SizedBox(
            width: 44,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _showSortSheet(context),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Icon(Icons.tune_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: context.read<WorkflowListCubit>().search,
              decoration: const InputDecoration(
                hintText: 'جستجو در گردش‌کارها...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
        ]),
      );

  Future<void> _showSortSheet(BuildContext context) async {
    final cubit = context.read<WorkflowListCubit>();
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('مرتب‌سازی گردش‌کارها',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          for (final option in const [
            ('modified desc', 'آخرین ویرایش'),
            ('modified asc', 'قدیمی‌ترین ویرایش'),
            ('title asc', 'عنوان'),
            ('code asc', 'کد فرایند'),
          ])
            ListTile(
              leading: Icon(
                cubit.state.orderBy == option.$1
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: cubit.state.orderBy == option.$1
                    ? AsoudColors.primary
                    : AsoudColors.muted,
              ),
              title: Text(option.$2),
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ]),
      ),
    );
    if (value != null) await cubit.setOrder(value);
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkflowListCubit, WorkflowListState>(
        buildWhen: (previous, current) => previous.filter != current.filter,
        builder: (context, state) => Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AsoudColors.border)),
          ),
          child: Row(children: [
            _FilterTab(label: 'همه', value: null, current: state.filter),
            _FilterTab(
                label: 'فعال',
                value: WorkflowDefinitionStatus.active,
                current: state.filter),
            _FilterTab(
                label: 'غیرفعال',
                value: WorkflowDefinitionStatus.inactive,
                current: state.filter),
            _FilterTab(
                label: 'آرشیو',
                value: WorkflowDefinitionStatus.archived,
                current: state.filter),
          ]),
        ),
      );
}

class _FilterTab extends StatelessWidget {
  const _FilterTab(
      {required this.label, required this.value, required this.current});
  final String label;
  final WorkflowDefinitionStatus? value, current;
  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return Expanded(
      child: InkWell(
        onTap: () => context.read<WorkflowListCubit>().setFilter(value),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AsoudColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? AsoudColors.primary : AsoudColors.muted,
              )),
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.item});
  final WorkflowDefinition item;

  @override
  Widget build(BuildContext context) {
    final visual = _workflowVisual(item.iconKey, item.status, item.isLocked);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            AsoudIconBox(icon: visual.$1, color: visual.$2, size: 43),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(item.code,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 9, color: AsoudColors.muted)),
                    const SizedBox(height: 5),
                    Text(_subtitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: item.isLocked
                              ? AsoudColors.warning
                              : AsoudColors.muted,
                        )),
                  ]),
            ),
            const SizedBox(width: 7),
            _StatusBadge(item: item),
            PopupMenuButton<String>(
              tooltip: 'عملیات فرایند',
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'details', child: Text('مشاهده جزئیات')),
                PopupMenuItem(
                  value: 'activate',
                  enabled: !item.isLocked,
                  child: Text(item.isLocked ? 'فعال‌سازی (قفل)' : 'فعال‌سازی'),
                ),
              ],
              onSelected: (value) {
                if (value == 'details') {
                  _showDetails(context);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  String _subtitle(WorkflowDefinition item) {
    if (item.isLocked) {
      return item.pendingReason ?? 'پیش‌نیازهای این فرایند کامل نشده است';
    }
    final date =
        item.modified == null ? 'ثبت نشده' : _jalaliDate(item.modified!);
    return '${item.stepsCount} مرحله • آخرین ویرایش: $date';
  }

  Future<void> _showDetails(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(item.title),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('کد: ${item.code}'),
                Text('سند مقصد: ${item.targetDoctype}'),
                Text('نسخه: ${item.version}'),
                if (item.isLocked) ...[
                  const SizedBox(height: 12),
                  const Text('موارد باقی‌مانده:',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  for (final requirement in item.missingRequirements)
                    Text('• $requirement'),
                ],
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'))
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});
  final WorkflowDefinition item;
  @override
  Widget build(BuildContext context) {
    final (label, color) = item.isLocked
        ? ('نیازمند تکمیل', AsoudColors.warning)
        : switch (item.status) {
            WorkflowDefinitionStatus.active => ('فعال', AsoudColors.success),
            WorkflowDefinitionStatus.inactive => ('غیرفعال', AsoudColors.muted),
            WorkflowDefinitionStatus.archived => ('آرشیو', AsoudColors.purple),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 8, color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const AsoudIconBox(
                icon: Icons.cloud_off_rounded,
                color: AsoudColors.warning,
                size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: context.read<WorkflowListCubit>().load,
                child: const Text('تلاش دوباره')),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('گردش‌کاری با این شرایط پیدا نشد.',
            style: TextStyle(color: AsoudColors.muted)),
      );
}

class _WorkflowBottomNavigation extends StatelessWidget {
  const _WorkflowBottomNavigation();
  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 2) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'این مسیر در مرحله بعد به صفحه اصلی مربوط متصل می‌شود.')),
          );
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'داشبورد'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded), label: 'اعلان‌ها'),
          NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub_rounded),
              label: 'گردش‌کار'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded), label: 'گزارش‌ها'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'بیشتر'),
        ],
      );
}

(IconData, Color) _workflowVisual(
    String? key, WorkflowDefinitionStatus status, bool locked) {
  if (locked) return (Icons.lock_clock_outlined, AsoudColors.warning);
  return switch (key) {
    'purchase' => (Icons.shopping_cart_outlined, AsoudColors.primary),
    'leave' => (Icons.description_outlined, AsoudColors.purple),
    'hiring' => (Icons.person_add_alt_1_outlined, AsoudColors.warning),
    'expense' => (Icons.account_balance_wallet_outlined, AsoudColors.success),
    'support' => (Icons.support_agent_rounded, const Color(0xFFEF476F)),
    _ => (
        Icons.hub_outlined,
        status == WorkflowDefinitionStatus.active
            ? AsoudColors.success
            : AsoudColors.muted
      ),
  };
}

String _orderLabel(String value) => switch (value) {
      'modified asc' => 'قدیمی‌ترین',
      'title asc' => 'عنوان',
      'code asc' => 'کد',
      _ => 'جدیدترین',
    };

String _jalaliDate(DateTime value) {
  var gy = value.year;
  final gm = value.month;
  final gd = value.day;
  var jy = gy > 1600 ? 979 : 0;
  gy -= gy > 1600 ? 1600 : 621;
  final gy2 = gm > 2 ? gy + 1 : gy;
  const monthDays = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  var days = 365 * gy +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) -
      80 +
      gd +
      monthDays[gm - 1];
  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}';
}
