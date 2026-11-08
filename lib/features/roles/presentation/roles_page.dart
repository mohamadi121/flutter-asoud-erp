import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/access_denied.dart';
import '../../../core/auth/capabilities.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/persian_server_values.dart';
import '../../../core/utils/persian_format.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../../../core/widgets/states.dart';
import '../data/role_repository.dart';
import '../../auth/data/account_repository.dart';
import '../../auth/domain/entities/login_state.dart';
import '../domain/role_catalog.dart';
import 'role_cubit.dart';

part 'role_form_page.dart';
part 'role_templates_page.dart';
part 'role_setup_page.dart';
part 'role_excel_page.dart';
part 'user_access_page.dart';
part 'role_permissions_page.dart';
part 'role_summary_sheet.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({this.repository, super.key});
  final RoleRepository? repository;
  @override
  Widget build(BuildContext context) => FutureBuilder<Capabilities>(
        future: capabilitiesOf(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final capabilities = snapshot.data!;
          if (!capabilities.canReadRoleCatalog) {
            return const AccessDeniedScaffold();
          }
          return BlocProvider(
            create: (_) => RoleCubit(
                repository ?? RoleRepository(context.read<FrappeApiClient>()))
              ..load(),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: _RoleSessionGuard(
                    child:
                        _RoleSetupView(canManage: capabilities.canManageRoles))),
          );
        },
      );
}

Future<T?> _roleRoute<T>(BuildContext context, Widget page) {
  final cubit = context.read<RoleCubit>();
  return Navigator.of(context).push<T>(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
          value: cubit,
          child: Directionality(
              textDirection: TextDirection.rtl,
              child: _RoleSessionGuard(child: page)))));
}

class _RoleSessionGuard extends StatelessWidget {
  const _RoleSessionGuard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => BlocConsumer<RoleCubit, RoleState>(
      listenWhen: (before, after) => !before.sessionEnded && after.sessionEnded,
      listener: (context, state) =>
          Navigator.of(context).popUntil((route) => route.isFirst),
      builder: (context, state) => state.sessionEnded
          ? const Scaffold(
              body: Center(child: Text('نشست تغییر کرده؛ دوباره وارد شوید.')))
          : child);
}

(IconData, Color) _roleStyle(String style) => switch (style) {
      'managers' => (Icons.groups_rounded, AsoudColors.purple),
      'finance' => (Icons.account_balance_rounded, AsoudColors.success),
      'sales' => (Icons.shopping_cart_rounded, AsoudColors.warning),
      'stock' => (Icons.inventory_2_outlined, AsoudColors.purple),
      'hr' => (Icons.people_alt_rounded, const Color(0xFFEC407A)),
      'purchase' => (Icons.local_shipping_outlined, const Color(0xFF00897B)),
      'employee' => (Icons.badge_outlined, AsoudColors.primary),
      _ => (Icons.settings_rounded, const Color(0xFF039BE5)),
    };

/// Shared completion badge for a role row and the role summary sheet.
Widget _roleStatusLabel(ManagedRole role) {
  final complete = role.completion == 'complete';
  return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: (complete ? AsoudColors.success : AsoudColors.warning)
              .withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(complete ? 'تکمیل‌شده' : 'نیازمند تکمیل',
          style: TextStyle(
              fontSize: 10,
              color: complete ? AsoudColors.success : AsoudColors.warning)));
}

class _RolesView extends StatefulWidget {
  const _RolesView({this.canManage = true});
  final bool canManage;
  @override
  State<_RolesView> createState() => _RolesViewState();
}

class _RolesViewState extends State<_RolesView> {
  String _query = '';
  String _statusFilter = 'all';
  String? _selected;
  final Set<String> _expanded = {};

  bool get _hasActiveFilter => _query.isNotEmpty || _statusFilter != 'all';

  /// A role matches the active search (title, description, or its category
  /// title, case-insensitive for latin) and the status filter. The English
  /// code is never a search field.
  bool _roleMatches(ManagedRole role, RoleCategory? category) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final hit = role.title.toLowerCase().contains(q) ||
          role.description.toLowerCase().contains(q) ||
          (category != null && category.title.toLowerCase().contains(q));
      if (!hit) return false;
    }
    if (_statusFilter == 'complete' && role.completion != 'complete') {
      return false;
    }
    if (_statusFilter == 'incomplete' && role.completion != 'incomplete') {
      return false;
    }
    return true;
  }

  Widget _statCards(RoleCatalog catalog) {
    final summary = catalog.summary;
    // The third card is shown only with real server data, never a guess.
    final incomplete = summary.incomplete;
    final cards = <(Key, String, String, Color)>[
      (const Key('stat_card_roles'), toPersianDigits(summary.roles),
          'کل نقش‌ها', AsoudColors.primary),
      (const Key('stat_card_categories'), toPersianDigits(summary.categories),
          'دسته‌بندی', AsoudColors.purple),
      if (incomplete != null)
        (const Key('stat_card_incomplete'), toPersianDigits(incomplete),
            'نیازمند تکمیل', AsoudColors.warning),
    ];
    return Row(children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
            child: Container(
                key: cards[i].$1,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: cards[i].$4.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(cards[i].$2,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(cards[i].$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.muted)),
                ]))),
      ],
    ]);
  }

  Widget _startGuide() {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    AsoudIconBox(
                        icon: Icons.badge_outlined,
                        color: AsoudColors.primary,
                        size: 44),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('نقشی ثبت نشده است',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 12),
                  const Text(
                      'برای شروع، یک نقش بسازید یا از قالب‌های آماده استفاده کنید.',
                      style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
                  if (widget.canManage) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: () => _roleRoute<bool>(
                              context, const _RoleTemplates()),
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('استفاده از قالب آماده')),
                      OutlinedButton.icon(
                          onPressed: () => _roleRoute<bool>(
                              context, const _RoleForm()),
                          icon: const Icon(Icons.add),
                          label: const Text('ایجاد نقش جدید')),
                      OutlinedButton.icon(
                          onPressed: () => _roleRoute<bool>(
                              context, const _RoleExcelPage()),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('ورود از اکسل')),
                    ]),
                  ],
                ])));
  }

  Widget _uncategorized(
      List<ManagedRole> roles, RoleState state, bool enabled) {
    final visible = roles.where((role) => _roleMatches(role, null)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: const AsoudIconBox(
                icon: Icons.category_outlined,
                color: AsoudColors.muted,
                size: 44),
            title: const Text('بدون دسته',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(formatCount(visible.length, 'نقش')),
          ),
          for (final node in _tree(visible))
            _roleRow(node.$1, node.$2, enabled, visible),
        ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: 'نقش‌ها',
            subtitle: 'نمای درختی نقش‌ها',
            action: IconButton(
                tooltip: 'بازخوانی',
                onPressed: context.read<RoleCubit>().load,
                icon: const Icon(Icons.refresh_rounded))),
        body: SafeArea(
            child: BlocBuilder<RoleCubit, RoleState>(builder: (context, state) {
          final enabled = state.loaded && !state.loading && !state.saving;
          final catalog = state.catalog;
          final managed = catalog.roles.where((role) => !role.system).toList();
          final hasCompletion =
              managed.any((role) => role.completion != null);
          final categoryByCode = {
            for (final category in catalog.categories) category.code: category
          };
          final uncategorized = managed
              .where((role) =>
                  !categoryByCode.containsKey(role.category.trim()))
              .toList();
          bool categoryHasMatch(RoleCategory category) =>
              !_hasActiveFilter ||
              catalog.roles.any((role) =>
                  role.category == category.code &&
                  _roleMatches(role, category));
          final noMatch = state.loaded &&
              _hasActiveFilter &&
              !catalog.categories.any(categoryHasMatch) &&
              !uncategorized.any((role) => _roleMatches(role, null));
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const _RoleStatus(),
                if (state.loaded) ...[
                  _statCards(catalog),
                  const SizedBox(height: 12),
                ],
                if (widget.canManage)
                  FilledButton.icon(
                      onPressed: !enabled ? null : () => _openCreate(state),
                      icon: const Icon(Icons.add),
                      label: const Text('ایجاد نقش')),
                if (widget.canManage) const SizedBox(height: 10),
                if (widget.canManage)
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: enabled
                                ? () => _roleRoute<bool>(
                                    context, const _RoleTemplates())
                                : null,
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text('الگوهای موجود'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: enabled
                                ? () => _roleRoute<bool>(
                                    context, const _CategoryForm())
                                : null,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('ایجاد دسته'))),
                  ]),
                const SizedBox(height: 12),
                TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: const InputDecoration(
                        hintText: 'جست‌وجو در نقش‌ها…',
                        prefixIcon: Icon(Icons.search))),
                if (state.loaded && hasCompletion) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final entry in const {
                      'all': 'همه',
                      'complete': 'تکمیل‌شده',
                      'incomplete': 'نیازمند تکمیل'
                    }.entries)
                      ChoiceChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFilter = entry.key);
                            }
                          }),
                  ]),
                ],
                const SizedBox(height: 14),
                if (state.loaded && managed.isEmpty) _startGuide(),
                if (noMatch)
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'نتیجه‌ای پیدا نشد',
                    description: 'با جست‌وجو یا فیلتر فعلی نقشی مطابقت نداشت.',
                    primaryActionLabel: 'پاک‌کردن جستجو',
                    onPrimaryAction: () => setState(() {
                      _query = '';
                      _statusFilter = 'all';
                    }),
                  ),
                for (final role in catalog.systemRoles)
                  if (_query.isEmpty ||
                      role.title.contains(_query) ||
                      role.description.contains(_query))
                    _systemRoleCard(role),
                if (state.loaded &&
                    (catalog.systemRoles.isEmpty || _query.isNotEmpty))
                  const SizedBox(height: 10),
                for (final category in catalog.categories)
                  _category(category, state, enabled),
                if (uncategorized.isNotEmpty)
                  _uncategorized(uncategorized, state, enabled),
                const SizedBox(height: 14),
              ]);
        })),
      );

  Future<void> _openCreate(RoleState state) async {
    if (state.catalog.categories.isEmpty) {
      final created =
          await _roleRoute<bool>(context, const _CategoryForm());
      if (created == true && mounted) {
        final latest = context.read<RoleCubit>().state;
        if (latest.loaded && latest.catalog.categories.isNotEmpty) {
          _roleRoute<bool>(
              context,
              _RoleForm(
                  category: latest.catalog.categories.last.code));
        }
      }
    } else {
      _roleRoute<bool>(context, const _RoleForm());
    }
  }

  /// A protected role of `catalog.system_roles` («مدیر کل سیستم»): global,
  /// never edited here, its full permission list is one tap away.
  Widget _systemRoleCard(ManagedRole role) => Card(
        child: ListTile(
          key: Key('system_role_${role.code}'),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: const AsoudIconBox(
              icon: Icons.verified_user_outlined,
              color: AsoudColors.purple,
              size: 44),
          title: Text(role.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            'سطح دسترسی: ${role.scopeLabel.isEmpty ? 'سراسری' : role.scopeLabel}',
            'دسترسی کامل',
            if (role.holders.isNotEmpty) formatCount(role.holders.length, 'دارنده'),
          ].join(' · ')),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _roleRoute<void>(context, _RolePermissions(role: role)),
        ),
      );

  Widget _category(RoleCategory category, RoleState state, bool enabled) {
    final style = _roleStyle(category.style);
    final all = state.catalog.roles
        .where((role) => role.category == category.code)
        .toList();
    final visible =
        all.where((role) => _roleMatches(role, category)).toList();
    // A category with no roles is still shown when nothing is filtered.
    if (_hasActiveFilter && visible.isEmpty) return const SizedBox.shrink();
    final open = _expanded.contains(category.code) || _hasActiveFilter;
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: AsoudIconBox(icon: style.$1, color: style.$2, size: 44),
            title: Text(category.title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(formatCount(all.length, 'نقش')),
            trailing: Icon(open ? Icons.expand_less : Icons.chevron_left),
            onTap: () => setState(() {
              if (!_expanded.add(category.code)) {
                _expanded.remove(category.code);
              }
            }),
          ),
          if (open) ...[
            for (final node in _tree(visible))
              _roleRow(node.$1, node.$2, enabled, visible),
            if (widget.canManage)
              TextButton.icon(
                  onPressed: enabled
                      ? () => _roleRoute<bool>(
                          context, _RoleForm(category: category.code))
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن نقش به این دسته')),
          ],
        ]));
  }

  List<(ManagedRole, int)> _tree(List<ManagedRole> roles) {
    final result = <(ManagedRole, int)>[];
    final visited = <String>{};
    final codes = roles.map((role) => role.code).toSet();
    final sorted = [...roles]..sort((a, b) => a.code.compareTo(b.code));
    void visit(ManagedRole role, int depth) {
      if (!visited.add(role.code)) return;
      result.add((role, depth));
      final children = sorted.where((item) => item.parent == role.code);
      // A status filter (not just a search) must also reveal matching children
      // under a collapsed matching parent.
      if (_expanded.contains('role:${role.code}') || _hasActiveFilter) {
        for (final child in children) {
          visit(child, depth + 1);
        }
      } else {
        // Hidden descendants must not be rendered again as orphan roots.
        void mark(String parent) {
          for (final child in sorted.where((item) => item.parent == parent)) {
            if (visited.add(child.code)) mark(child.code);
          }
        }

        mark(role.code);
      }
    }

    for (final role in sorted.where((role) => !codes.contains(role.parent))) {
      visit(role, 0);
    }
    // Defensive recovery for malformed cached cycles; every row remains editable.
    for (final role in sorted) {
      if (!visited.contains(role.code)) visit(role, 0);
    }
    return result;
  }

  Widget _roleRow(
      ManagedRole role, int depth, bool enabled, List<ManagedRole> roles) {
    final hasChildren = roles.any((item) => item.parent == role.code);
    return Padding(
        padding: EdgeInsetsDirectional.only(
            start: 12 + (depth.clamp(0, 6) * 12).toDouble(), end: 4),
        child: ListTile(
          dense: true,
          selected: _selected == role.code,
          leading: Icon(
              hasChildren ? Icons.folder_outlined : Icons.badge_outlined,
              color: AsoudColors.primary),
          title: Text(persianRoleLabel(role.title.isNotEmpty ? role.title : role.code)),
          subtitle: Text(
              [
                if (role.scope.isNotEmpty) 'سطح دسترسی: ${role.scopeLabel}',
                if (role.description.isNotEmpty)
                  role.description
                else if (persianRoleLabel(role.code) != persianRoleLabel(role.title))
                  persianRoleLabel(role.code),
                if (context.read<RoleCubit>().repository.isDraft(role.code)) 'محلی',
                if (!role.enabled) 'غیرفعال',
              ].join(' · '),
              style: const TextStyle(fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (role.completion != null) ...[
              _roleStatusLabel(role),
              const SizedBox(width: 6),
            ],
            if (hasChildren)
              IconButton(
                  key: Key('role_expand_${role.code}'),
                  tooltip: 'نمایش زیرمجموعه‌ها',
                  onPressed: () => setState(() {
                        if (!_expanded.add('role:${role.code}')) {
                          _expanded.remove('role:${role.code}');
                        }
                      }),
                  icon: Icon(_expanded.contains('role:${role.code}')
                      ? Icons.expand_less
                      : Icons.expand_more)),
            if (widget.canManage || role.system)
              PopupMenuButton<String>(
                  enabled: enabled,
                  tooltip: 'عملیات نقش',
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'permissions', child: Text('مشاهده مجوزها')),
                      if (!role.system) ...[
                      const PopupMenuItem(
                          value: 'child', child: Text('افزودن زیرمجموعه')),
                      const PopupMenuItem(
                          value: 'edit', child: Text('ویرایش نقش')),
                      const PopupMenuItem(
                          value: 'users', child: Text('کاربران و دسترسی‌ها')),
                      PopupMenuItem(
                          value: 'status',
                          child: Text(role.enabled
                              ? 'غیرفعال‌کردن نقش'
                              : 'فعال‌کردن نقش')),
                      ],
                    ],
                onSelected: (action) {
                  if (action == 'permissions') {
                    _roleRoute<void>(context, _RolePermissions(role: role));
                  } else if (action == 'child') {
                    _roleRoute<bool>(context,
                        _RoleForm(category: role.category, parent: role.code));
                  } else if (action == 'edit') {
                    _roleRoute<bool>(context, _RoleForm(role: role));
                  } else if (action == 'users') {
                    _roleRoute<void>(
                        context,
                        UserAccessPage(
                            role: role,
                            repository: UserAccessRepository(context
                                .read<RoleCubit>()
                                .repository
                                .client)));
                  } else {
                    _changeStatus(role);
                  }
                }),
          ]),
          onTap: () {
            // Opening the sheet no longer expands the role's children; the
            // trailing expand button owns that.
            setState(() => _selected = role.code);
            _showRoleSummary(context, role, canManage: widget.canManage);
          },
        ));
  }

  Future<void> _changeStatus(ManagedRole role) async {
    if (role.enabled && role.assignedUsers > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'پیش از غیرفعال‌سازی، تخصیص این نقش به کاربران را تغییر دهید.')));
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(role.enabled ? 'غیرفعال‌کردن نقش' : 'فعال‌کردن نقش'),
              content: Text(
                  'وضعیت نقش «${persianRoleLabel(role.title)}» تغییر کند؟ دسترسی‌های تعریف‌شده تغییر نمی‌کنند.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('تأیید')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    await context.read<RoleCubit>().save(ManagedRole(
          code: role.code,
          title: role.title,
          category: role.category,
          parent: role.parent,
          description: role.description,
          enabled: !role.enabled,
          baseRoles: role.baseRoles,
          modified: role.modified,
          profileModified: role.profileModified,
          assignedUsers: role.assignedUsers,
        ));
  }
}

class _RoleHint extends StatelessWidget {
  const _RoleHint(this.text, {this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: (error ? AsoudColors.warning : AsoudColors.primary)
                .withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline : Icons.info_outline,
              color: error ? AsoudColors.warning : AsoudColors.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 11, height: 1.7))),
        ]),
      );
}

class _RoleStatus extends StatelessWidget {
  const _RoleStatus();
  @override
  Widget build(BuildContext context) => BlocBuilder<RoleCubit, RoleState>(
      builder: (context, state) => Column(children: [
            if (context.read<RoleCubit>().repository.offline)
              const _RoleHint(
                  'ذخیره روی گوشی؛ اعمال دسترسی فقط با تأیید سرور.'),
            if (context.read<RoleCubit>().repository.isPreview)
              const _RoleHint('فضای محلی بدون ورود؛ مستقل از حساب کاربران.'),
            if (context.read<RoleCubit>().repository.pendingCount > 0) ...[
              _RoleHint(
                  '${toPersianDigits(context.read<RoleCubit>().repository.pendingCount)} پیش‌نویس روی گوشی؛ هنوز روی سرور تأیید نشده است.'),
              Wrap(children: [
                TextButton(
                    onPressed: state.loading || state.saving
                        ? null
                        : context.read<RoleCubit>().synchronize,
                    child: const Text('ارسال پیش‌نویس‌ها به سرور')),
                TextButton(
                    onPressed: state.loading || state.saving
                        ? null
                        : () => _discard(context),
                    child: const Text('کنارگذاشتن پیش‌نویس و دریافت سرور')),
              ]),
            ],
            if (state.loading || state.saving)
              const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator()),
            if (state.error != null) ...[
              _RoleHint(state.error!, error: true),
              TextButton(
                  onPressed: state.loading || state.saving
                      ? null
                      : context.read<RoleCubit>().load,
                  child: const Text('بازخوانی از سرور')),
            ],
          ]));

  Future<void> _discard(BuildContext context) async {
    final cubit = context.read<RoleCubit>();
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('بازگشت به اطلاعات سرور'),
                content: const Text(
                    'همه پیش‌نویس‌های این حساب بایگانی می‌شوند و از فهرست کار خارج می‌شوند. فقط پس از دریافت موفق سرور انجام می‌شود. ادامه می‌دهید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('تأیید')),
                ]));
    if (confirm == true && context.mounted) await cubit.discardDrafts();
  }
}
