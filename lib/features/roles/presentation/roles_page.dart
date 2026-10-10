import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/persian_format.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../data/role_repository.dart';
import '../domain/role_catalog.dart';
import 'role_cubit.dart';

part 'role_form_page.dart';
part 'role_templates_page.dart';
part 'role_setup_page.dart';
part 'role_excel_page.dart';
part 'user_access_page.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({this.repository, super.key});
  final RoleRepository? repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => RoleCubit(
            repository ?? RoleRepository(context.read<FrappeApiClient>()))
          ..load(),
        child: const Directionality(
            textDirection: TextDirection.rtl,
            child: _RoleSessionGuard(child: _RoleSetupView())),
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

class _RolesView extends StatefulWidget {
  const _RolesView();
  @override
  State<_RolesView> createState() => _RolesViewState();
}

class _RolesViewState extends State<_RolesView> {
  String _query = '';
  String? _selected;
  final Set<String> _expanded = {};

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
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const _RoleStatus(),
                FilledButton.icon(
                    onPressed: !enabled
                        ? null
                        : () async {
                            if (state.catalog.categories.isEmpty) {
                              final created = await _roleRoute<bool>(
                                  context, const _CategoryForm());
                              if (created == true && context.mounted) {
                                final latest = context.read<RoleCubit>().state;
                                if (latest.loaded &&
                                    latest.catalog.categories.isNotEmpty) {
                                  _roleRoute<bool>(
                                      context,
                                      _RoleForm(
                                          category: latest
                                              .catalog.categories.last.code));
                                }
                              }
                            } else {
                              _roleRoute<bool>(context, const _RoleForm());
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('ایجاد نقش')),
                const SizedBox(height: 10),
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
                const SizedBox(height: 14),
                if (state.loaded &&
                    state.catalog.categories.isEmpty &&
                    state.catalog.roles.isEmpty)
                  const _RoleHint(
                      'هنوز دسته یا نقشی ثبت نشده است؛ از الگوهای آماده استفاده کنید یا ابتدا یک دسته بسازید.'),
                for (final category in state.catalog.categories)
                  if (_query.isEmpty ||
                      category.title.contains(_query) ||
                      state.catalog.roles.any((role) =>
                          role.category == category.code &&
                          (role.title.contains(_query) ||
                              role.code
                                  .toLowerCase()
                                  .contains(_query.toLowerCase()))))
                    _category(category, state, enabled),
                const SizedBox(height: 14),
              ]);
        })),
      );

  Widget _category(RoleCategory category, RoleState state, bool enabled) {
    final style = _roleStyle(category.style);
    final all = state.catalog.roles
        .where((role) => role.category == category.code)
        .toList();
    final visible = all
        .where((role) =>
            _query.isEmpty ||
            category.title.contains(_query) ||
            role.title.contains(_query) ||
            role.code.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final open = _expanded.contains(category.code) || _query.isNotEmpty;
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
      if (_expanded.contains('role:${role.code}') || _query.isNotEmpty) {
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
          title: Text(role.title),
          subtitle: Text(
              '${role.code}${context.read<RoleCubit>().repository.isDraft(role.code) ? ' · محلی' : ''}${role.enabled ? '' : ' · غیرفعال'}',
              style: const TextStyle(fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (hasChildren)
              Icon(_expanded.contains('role:${role.code}')
                  ? Icons.expand_less
                  : Icons.expand_more),
            PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'عملیات نقش',
                itemBuilder: (_) => [
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
                onSelected: (action) {
                  if (action == 'child') {
                    _roleRoute<bool>(context,
                        _RoleForm(category: role.category, parent: role.code));
                  } else if (action == 'edit') {
                    _roleRoute<bool>(context, _RoleForm(role: role));
                  } else if (action == 'users') {
                    _roleRoute<void>(context, _RoleUsersPage(role: role));
                  } else {
                    _changeStatus(role);
                  }
                }),
          ]),
          onTap: () {
            setState(() {
              _selected = role.code;
              if (!_expanded.add('role:${role.code}')) {
                _expanded.remove('role:${role.code}');
              }
            });
            if (!hasChildren && enabled) {
              _roleRoute<bool>(context, _RoleForm(role: role));
            }
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
                  'وضعیت نقش «${role.title}» تغییر کند؟ دسترسی‌های تعریف‌شده تغییر نمی‌کنند.'),
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
