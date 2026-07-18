import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../cubit/offices_cubit.dart';
import 'office_type_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class OfficesPage extends StatelessWidget {
  const OfficesPage(
      {this.initialState,
      this.showCreatedBanner = false,
      this.fallbackOffice,
      super.key});
  final OfficesState? initialState;
  final bool showCreatedBanner;
  final Office? fallbackOffice;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          final cubit = OfficesCubit(
            repository: context.read<OfficeRepository>(),
            initialState: initialState,
          );
          if (initialState == null) {
            cubit.load(
              fallbackOffice: fallbackOffice,
              showCreatedBanner: showCreatedBanner,
            );
          }
          return cubit;
        },
        child: const _OfficesView(),
      );
}

class _OfficesView extends StatelessWidget {
  const _OfficesView();

  @override
  Widget build(BuildContext context) => BlocBuilder<OfficesCubit, OfficesState>(
        builder: (context, state) => Scaffold(
          appBar: AsoudHeader(
            title: 'دفترهای من',
            subtitle: 'مدیریت و انتخاب دفترهای کاری',
            action: IconButton(
              tooltip: 'منوی بیشتر',
              onPressed: () => _unavailable(context),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          body: SafeArea(child: _body(context, state)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 2,
            onDestinationSelected: (index) {
              if (index != 2) _unavailable(context);
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: 'خانه'),
              NavigationDestination(
                  icon: Icon(Icons.list_alt_rounded), label: 'منوها'),
              NavigationDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business_rounded),
                  label: 'دفترها'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded), label: 'گزارش‌ها'),
            ],
          ),
        ),
      );

  Widget _body(BuildContext context, OfficesState state) {
    if (state.status == OfficesStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == OfficesStatus.error) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'دریافت دفترها ممکن نشد',
        message: state.message ?? 'خطای ناشناخته',
        actionLabel: 'تلاش مجدد',
        onAction: context.read<OfficesCubit>().retry,
      );
    }
    if (state.status == OfficesStatus.empty || state.offices.isEmpty) {
      return _MessageState(
        icon: Icons.business_outlined,
        title: 'هنوز دفتری ندارید',
        message: 'برای شروع، اولین دفتر کاری خود را ایجاد کنید.',
        actionLabel: 'ایجاد دفتر کار جدید',
        onAction: () => _create(context),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (state.offlinePreview) ...[
          const _OfflineBanner(),
          const SizedBox(height: 16),
        ],
        if (state.showCreatedBanner) ...[
          _SuccessBanner(
              onClose: context.read<OfficesCubit>().dismissCreatedBanner),
          const SizedBox(height: 16),
        ],
        if (state.defaultOffice case final office?) ...[
          const AsoudSectionTitle(title: 'دفتر پیش‌فرض'),
          _OfficeCard(
              office: office, onMenu: () => _showActions(context, office)),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DashboardPage(
                    officeName: office.name,
                    offlinePreview: state.offlinePreview,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('ورود به دفتر کار'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AsoudColors.primary, width: 1.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('ایجاد دفتر کار جدید'),
          ),
        ),
        const SizedBox(height: 22),
        const AsoudSectionTitle(title: 'دفترهای موجود'),
        SizedBox(
          height: 44,
          child: TextField(
            key: const ValueKey('office-search'),
            onChanged: context.read<OfficesCubit>().search,
            decoration: const InputDecoration(
              hintText: 'جست‌وجو در دفترها...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.filteredOffices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('دفتری با این عبارت پیدا نشد.',
                textAlign: TextAlign.center),
          )
        else
          ...state.filteredOffices.map((office) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OfficeCard(
                    office: office,
                    onMenu: () => _showActions(context, office)),
              )),
      ],
    );
  }

  void _create(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const OfficeTypePage()));

  void _unavailable(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('این قابلیت هنوز به Backend متصل نشده است.')));

  Future<void> _showActions(BuildContext context, Office office) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('عملیات دفتر',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final item in const [
                ('مشاهده اطلاعات دفتر', Icons.visibility_outlined, false),
                ('ویرایش اطلاعات دفتر', Icons.edit_outlined, false),
                ('مدیریت سال مالی', Icons.calendar_month_outlined, false),
                ('غیرفعال‌کردن دفتر', Icons.block_outlined, false),
                ('حذف دفتر', Icons.delete_outline_rounded, true),
              ])
                ListTile(
                  enabled: false,
                  leading:
                      Icon(item.$2, color: item.$3 ? AsoudColors.danger : null),
                  title: Text(item.$1,
                      style: TextStyle(
                          color: item.$3 ? AsoudColors.danger : null)),
                  subtitle: const Text('نیازمند API'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('بستن')),
            ]),
          ),
        ),
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.onClose});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F0),
          border: Border.all(color: AsoudColors.success.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AsoudColors.success),
          const SizedBox(width: 8),
          const Expanded(child: Text('دفتر کار با موفقیت ایجاد شد')),
          IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              visualDensity: VisualDensity.compact),
        ]),
      );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.cloud_off_rounded, color: AsoudColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'حالت موقت آفلاین؛ این دفتر هنوز در ERPNext ذخیره نشده است.',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ]),
      );
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office, required this.onMenu});
  final Office office;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Card(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AsoudIconBox(
                icon: office.type == OfficeType.legal
                    ? Icons.apartment_rounded
                    : Icons.person_rounded,
                color: office.type == OfficeType.legal
                    ? AsoudColors.primary
                    : AsoudColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(office.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      office.type == OfficeType.legal
                          ? 'حقوقی • ${office.city?.isNotEmpty == true ? office.city : 'تهران'}، ایران'
                          : 'حقیقی • ${office.city?.isNotEmpty == true ? office.city : 'تهران'}، ایران',
                      style: const TextStyle(
                          color: AsoudColors.muted, fontSize: 10),
                    ),
                    const SizedBox(height: 13),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Badge(
                          label: office.type == OfficeType.legal
                              ? 'حقوقی'
                              : 'حقیقی',
                          color: AsoudColors.primary),
                      const _Badge(label: 'فعال', color: AsoudColors.success),
                      _Badge(
                        label:
                            'سال مالی ${office.fiscalYear?.isNotEmpty == true ? office.fiscalYear : _persianFiscalYear(office.fiscalYearStart)}',
                        color: AsoudColors.warning,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'آخرین همگام‌سازی: ${_syncLabel(office.lastSyncedAt)}',
                      style: const TextStyle(
                        color: AsoudColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ])),
              IconButton(
                  key: ValueKey('office-menu-${office.name}'),
                  onPressed: onMenu,
                  icon: const Icon(Icons.more_vert_rounded)),
            ]),
          ),
          const Divider(height: 1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8F0),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: const Text('دفتر فعال',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AsoudColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  static String _persianFiscalYear(DateTime date) {
    final year = date.year > 1700 ? date.year - 621 : date.year;
    const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return year
        .toString()
        .split('')
        .map((value) => digits[int.parse(value)])
        .join();
  }

  static String _syncLabel(DateTime? value) {
    if (value == null) return 'زمان ثبت نشده';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}، ${local.year}/${two(local.month)}/${two(local.day)}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)));
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon,
      required this.title,
      required this.message,
      required this.actionLabel,
      required this.onAction});
  final IconData icon;
  final String title, message, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            AsoudIconBox(icon: icon, color: AsoudColors.primary, size: 56),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AsoudColors.muted, fontSize: 11)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ]),
        ),
      );
}
