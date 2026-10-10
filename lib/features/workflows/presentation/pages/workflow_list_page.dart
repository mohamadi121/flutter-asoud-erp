import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/access_denied.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../../domain/repositories/workflow_notification_repository.dart';
import '../cubit/workflow_list_cubit.dart';
import 'workflow_form_page.dart';
import 'workflow_notifications_page.dart';
import 'workflow_designer_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

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
        child: _WorkflowCapabilityGate(onCreate: onCreate),
      );
}

class _WorkflowCapabilityGate extends StatelessWidget {
  const _WorkflowCapabilityGate({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => FutureBuilder<Capabilities>(
      future: capabilitiesOf(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final capabilities = snapshot.data!;
        if (!capabilities.canReadManagerViews) {
          return const AccessDeniedScaffold();
        }
        return _WorkflowListView(
            onCreate: onCreate,
            canManageWorkflows: capabilities.canManageWorkflows);
      });
}

class _WorkflowListView extends StatelessWidget {
  const _WorkflowListView({this.onCreate, required this.canManageWorkflows});
  final VoidCallback? onCreate;
  final bool canManageWorkflows;

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
                    return ErrorState(
                        failure: state.message ?? 'خطای نامشخص',
                        onRetry: context.read<WorkflowListCubit>().load);
                  }
                  if (state.items.isEmpty) {
                    return const EmptyState(
                        icon: Icons.account_tree_outlined,
                        title: 'گردش‌کاری پیدا نشد',
                        description: 'شرایط جست‌وجو یا فیلتر را تغییر دهید.');
                  }
                  return RefreshIndicator(
                    onRefresh: context.read<WorkflowListCubit>().load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 9, 16, 128),
                      children: [
                        Row(children: [
                          Text('مرتب‌سازی: ${_orderLabel(state.orderBy)}',
                              style: const TextStyle(
                                  fontSize: 9, color: AsoudColors.muted)),
                          const Spacer(),
                          Text('تعداد کل: ${toPersianDigits(state.items.length)}',
                              style: const TextStyle(
                                  fontSize: 9, color: AsoudColors.muted)),
                        ]),
                        const SizedBox(height: 8),
                        for (final item in state.items)
                          _WorkflowCard(
                              item: item,
                              canManageWorkflows: canManageWorkflows),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: canManageWorkflows
            ? Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width - 32,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onCreate ??
                        () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const WorkflowFormPage(),
                            )),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('ایجاد گردش‌کار جدید'),
                  ),
                ),
              )
            : null,
        bottomNavigationBar: const _WorkflowBottomNavigation(),
      );
}

class _Header extends StatefulWidget {
  const _Header();
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late Future<int> _unread;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    try {
      _unread = context
          .read<WorkflowNotificationRepository>()
          .getNotifications(unreadOnly: true)
          .then((items) => items.length)
          .catchError((_) => 0);
    } on ProviderNotFoundException {
      _unread = Future.value(0);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 8),
        child: Row(children: [
          IconButton(
            tooltip: 'اعلان‌ها',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const WorkflowNotificationsPage()),
              );
              if (mounted) setState(_refresh);
            },
            icon: FutureBuilder<int>(
              future: _unread,
              builder: (_, snapshot) => Badge(
                isLabelVisible: (snapshot.data ?? 0) > 0,
                label: Text('${snapshot.data ?? 0}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
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
  const _WorkflowCard({required this.item, required this.canManageWorkflows});
  final WorkflowDefinition item;
  final bool canManageWorkflows;

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
            if (canManageWorkflows)
              PopupMenuButton<String>(
                tooltip: 'عملیات فرایند',
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'details', child: Text('مشاهده جزئیات')),
                  const PopupMenuItem(
                      value: 'design',
                      child: Text('طراحی مراحل و فرم درخواست')),
                  PopupMenuItem(
                    value: 'activate',
                    enabled: !item.isLocked,
                    child:
                        Text(item.isLocked ? 'فعال‌سازی (قفل)' : 'فعال‌سازی'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'details') {
                    _showDetails(context);
                  } else if (value == 'design') {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => WorkflowDesignerPage(definition: item.id),
                    ));
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
    final date = item.modified == null
        ? 'ثبت نشده'
        : toPersianDigits(JalaliDate.fromDateTime(item.modified!).format());
    return '${toPersianDigits(item.stepsCount)} مرحله • آخرین ویرایش: $date';
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
                Text('سند مقصد: ${persianDoctypeLabel(item.targetDoctype)}'),
                Text('نسخه: ${toPersianDigits(item.version)}'),
                if (item.isLocked) ...[
                  const SizedBox(height: 12),
                  const Text('موارد باقی‌مانده:',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  for (final requirement in item.missingRequirements)
                    Text('• $requirement'),
                ],
              ]),
          actions: [
            OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => WorkflowDesignerPage(definition: item.id)));
                },
                child: const Text('طراحی مراحل')),
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
    final (label, color, surface) = item.isLocked
        ? ('نیازمند تکمیل', AsoudColors.warning, AsoudColors.warningSurface)
        : switch (item.status) {
            WorkflowDefinitionStatus.active =>
              ('فعال', AsoudColors.success, AsoudColors.successSurface),
            WorkflowDefinitionStatus.inactive =>
              ('غیرفعال', AsoudColors.muted, AsoudColors.border),
            WorkflowDefinitionStatus.archived =>
              ('آرشیو', AsoudColors.purple, Color(0xFFF1E8FD)),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 8, color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _WorkflowBottomNavigation extends StatelessWidget {
  const _WorkflowBottomNavigation();
  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 2) return;
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const WorkflowNotificationsPage()),
            );
            return;
          }
          if (index == 0 || index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      const DashboardLandingPage(offlinePreview: true)),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const WorkflowComingSoonPage()),
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

class WorkflowComingSoonPage extends StatelessWidget {
  const WorkflowComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: AsoudHeader(title: 'گزارش‌ها'),
        body: ComingSoonState(
            description:
                'گزارش‌های این بخش در نسخه‌های بعدی در دسترس خواهد بود.'),
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
