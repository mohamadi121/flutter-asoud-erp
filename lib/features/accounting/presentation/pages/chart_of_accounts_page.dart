import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import '../cubit/chart_of_accounts_cubit.dart';
import 'account_form_page.dart';

class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({this.company, this.repository, super.key});
  final String? company;
  final ChartOfAccountsRepository? repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ChartOfAccountsCubit(
          company: company,
          repository: repository,
        )..load(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _ChartOfAccountsView(company: company, repository: repository),
        ),
      );
}

class _ChartOfAccountsView extends StatefulWidget {
  const _ChartOfAccountsView({required this.company, required this.repository});
  final String? company;
  final ChartOfAccountsRepository? repository;
  @override
  State<_ChartOfAccountsView> createState() => _ChartOfAccountsViewState();
}

class _ChartOfAccountsViewState extends State<_ChartOfAccountsView> {
  int _view = 0;
  String _query = '';
  AccountLevel? _level;
  final List<String> _path = [];

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _view != 1 || _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _view == 1 && _path.isNotEmpty) {
          setState(() {
            _path.removeLast();
            _query = '';
          });
        }
      },
      child: Scaffold(
        appBar: const AsoudHeader(
            title: 'سرفصل‌های حسابداری',
            subtitle: 'ساختار گروه، کل، معین و تفصیلی'),
        body: SafeArea(child:
            BlocBuilder<ChartOfAccountsCubit, ChartOfAccountsState>(
                builder: (context, state) {
          final filtered = _filterTree(state.accounts);
          final parent =
              _path.isEmpty ? null : _find(state.accounts, _path.last);
          final visible = _view == 0
              ? filtered
              : (parent?.children ??
                      state.accounts
                          .where((a) => a.level == AccountLevel.group)
                          .toList())
                  .where((a) =>
                      _query.isEmpty ||
                      a.title.contains(_query) ||
                      a.code.contains(_query))
                  .toList();
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              children: [
                if (state.status == ChartStatus.loading)
                  const LinearProgressIndicator(),
                if (state.status == ChartStatus.failure) ...[
                  _ChartMessage(
                    message: state.message ?? 'دریافت اطلاعات ممکن نشد.',
                    onRetry: context.read<ChartOfAccountsCubit>().load,
                  ),
                  const SizedBox(height: 12),
                ],
                AsoudSegmentedControl<int>(
                  value: _view,
                  options: const [
                    AsoudSegmentedOption(
                        value: 0,
                        icon: Icons.account_tree_outlined,
                        label: 'نمای درختی'),
                    AsoudSegmentedOption(
                        value: 1,
                        icon: Icons.view_list_outlined,
                        label: 'نمای مرحله‌ای'),
                  ],
                  onChanged: (value) => setState(() {
                    _view = value;
                    _query = '';
                    _level = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                    key: ValueKey('account-search-$_view-${_path.join('/')}'),
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'جست‌وجوی کد یا عنوان حساب',
                        suffixIcon: _view == 1
                            ? null
                            : IconButton(
                                onPressed: _chooseLevel,
                                icon: const Icon(Icons.filter_list_rounded)))),
                if (_level != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InputChip(
                      label: Text('سطح: ${_levelTitle(_level!)}'),
                      onDeleted: () => setState(() => _level = null),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (_view == 1) ...[
                  Row(children: [
                    if (_path.isNotEmpty)
                      IconButton(
                          key: const ValueKey('stage-back'),
                          tooltip: 'بازگشت به سطح قبل',
                          onPressed: () => setState(() {
                                _path.removeLast();
                                _query = '';
                              }),
                          icon: const Icon(Icons.arrow_forward_rounded)),
                    Expanded(
                        child: Text(
                            parent == null
                                ? 'گروه‌های حساب'
                                : '${parent.level == AccountLevel.group ? 'حساب‌های کل' : 'حساب‌های معین'} · ${parent.title}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                  if (parent != null && !parent.isTerminal)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: FilledButton.icon(
                            onPressed: () => _addTo(parent),
                            icon: const Icon(Icons.add),
                            label: Text(parent.level == AccountLevel.group
                                ? 'افزودن حساب کل'
                                : 'افزودن حساب معین'))),
                ],
                if (visible.isEmpty)
                  const _EmptyAccounts()
                else if (_view == 1)
                  ...visible.map((account) => Card(
                        key: ValueKey('stage-${account.id}'),
                        child: ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                              start: 12, end: 2),
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(account.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(_levelTitle(account.level)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(account.code,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            _AccountMenu(
                                account: account,
                                company: widget.company,
                                repository: widget.repository),
                          ]),
                          onTap: () {
                            if (account.isTerminal) {
                              _editStage(account);
                            } else {
                              setState(() {
                                _path.add(account.id);
                                _query = '';
                              });
                            }
                          },
                        ),
                      ))
                else
                  Card(
                    key: const ValueKey('account-tree-card'),
                    elevation: 0,
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AsoudColors.border),
                    ),
                    child: Column(
                        children: visible
                            .map((account) => _AccountTile(
                                  account: account,
                                  company: widget.company,
                                  repository: widget.repository,
                                ))
                            .toList()),
                  ),
              ]);
        })),
      ));

  List<AccountNode> _filterTree(List<AccountNode> accounts) => accounts
      .map((account) {
        final children = _filterTree(account.children);
        final queryMatches = _query.isEmpty ||
            account.title.contains(_query) ||
            account.code.contains(_query);
        final levelMatches = _level == null || account.level == _level;
        return queryMatches && levelMatches || children.isNotEmpty
            ? AccountNode(
                id: account.id,
                code: account.code,
                title: account.title,
                level: account.level,
                parentId: account.parentId,
                isActive: account.isActive,
                nature: account.nature,
                accountType: account.accountType,
                detailGroupIds: account.detailGroupIds,
                children: children,
              )
            : null;
      })
      .whereType<AccountNode>()
      .toList(growable: false);

  AccountNode? _find(List<AccountNode> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row;
      final found = _find(row.children, id);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _addTo(AccountNode parent) async {
    final saved = await Navigator.of(context).push<AccountNode>(
        MaterialPageRoute(
            builder: (_) => AccountFormPage(
                company: widget.company,
                repository: widget.repository,
                initialParentId: parent.id,
                initialLevel: AccountLevel.values[parent.level.index + 1])));
    if (saved != null && mounted) context.read<ChartOfAccountsCubit>().load();
  }

  Future<void> _editStage(AccountNode account) async {
    final saved = await Navigator.of(context).push<AccountNode>(
        MaterialPageRoute(
            builder: (_) => AccountFormPage(
                company: widget.company,
                repository: widget.repository,
                account: account)));
    if (saved != null && mounted) context.read<ChartOfAccountsCubit>().load();
  }

  Future<void> _chooseLevel() async {
    final selected = await showModalBottomSheet<AccountLevel?>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<AccountLevel>(
          groupValue: _level,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
                title: Text('فیلتر سطح حساب',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            for (final level in AccountLevel.values)
              RadioListTile<AccountLevel>(
                value: level,
                title: Text(_levelTitle(level)),
              ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('نمایش همه')),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _level = selected);
  }

  String _levelTitle(AccountLevel level) => switch (level) {
        AccountLevel.group => 'گروه',
        AccountLevel.general => 'کل',
        AccountLevel.ledger => 'معین',
        AccountLevel.detail => 'تفصیلی',
      };
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .08),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AsoudColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 10))),
          TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
        ]),
      );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          AsoudIconBox(
              icon: Icons.search_off_rounded,
              color: AsoudColors.muted,
              size: 52),
          SizedBox(height: 12),
          Text('حسابی با این مشخصات پیدا نشد.',
              style: TextStyle(color: AsoudColors.muted)),
        ]),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.company,
    required this.repository,
  });
  final AccountNode account;
  final String? company;
  final ChartOfAccountsRepository? repository;
  @override
  Widget build(BuildContext context) {
    final hasChildren = account.children.isNotEmpty;
    final color = _levelColor(account.level);
    final horizontalInset = switch (account.level) {
      AccountLevel.group => 0.0,
      AccountLevel.general => 0.0,
      AccountLevel.ledger => 0.0,
      AccountLevel.detail => 0.0,
    };
    final tileHeight = switch (account.level) {
      AccountLevel.group => 64.0,
      AccountLevel.general => 60.0,
      AccountLevel.ledger => 56.0,
      AccountLevel.detail => 52.0,
    };
    if (hasChildren) {
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            key: PageStorageKey('account-${account.id}'),
            initiallyExpanded: true,
            minTileHeight: tileHeight,
            tilePadding: const EdgeInsetsDirectional.only(start: 12, end: 2),
            leading: Icon(
                account.level == AccountLevel.group
                    ? Icons.folder_rounded
                    : Icons.folder_open_outlined,
                color: color),
            title: Text(account.title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(account.code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AsoudColors.muted)),
              _AccountMenu(
                  account: account, company: company, repository: repository),
            ]),
            children: account.children
                .map((child) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _AccountTile(
                      account: child,
                      company: company,
                      repository: repository,
                    )))
                .toList(),
          ));
    }
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: SizedBox(
            height: tileHeight,
            child: ListTile(
              leading: Icon(
                  switch (account.level) {
                    AccountLevel.group => Icons.folder_rounded,
                    AccountLevel.general => Icons.folder_open_outlined,
                    _ => Icons.description_outlined,
                  },
                  color: color),
              title: Text(account.title),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(account.code,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AsoudColors.muted)),
                _AccountMenu(
                    account: account, company: company, repository: repository),
              ]),
            )));
  }

  Color _levelColor(AccountLevel level) => switch (level) {
        AccountLevel.group => AsoudColors.primary,
        AccountLevel.general => const Color(0xFF26A69A),
        AccountLevel.ledger => const Color(0xFF26A69A),
        AccountLevel.detail => const Color(0xFFEF6C5B),
      };
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu(
      {required this.account, required this.company, required this.repository});
  final AccountNode account;
  final String? company;
  final ChartOfAccountsRepository? repository;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        key: ValueKey('account-menu-${account.id}'),
        tooltip: 'عملیات سرفصل: ویرایش، زیرمجموعه و حذف',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'edit') {
            _edit(context);
          } else if (value == 'add') {
            _addChild(context);
          } else if (value == 'delete') {
            _delete(context);
          }
        },
        itemBuilder: (_) => [
          if (!account.isTerminal)
            const PopupMenuItem(
              value: 'add',
              child: ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('افزودن زیرمجموعه'),
              ),
            ),
          const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                  leading: Icon(Icons.edit_outlined), title: Text('ویرایش'))),
          const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('حذف', style: TextStyle(color: Colors.red)))),
        ],
      );

  Future<void> _addChild(BuildContext context) async {
    if (account.level == AccountLevel.detail) return;
    final saved = await Navigator.of(context).push<AccountNode>(
      MaterialPageRoute<AccountNode>(
        builder: (_) => AccountFormPage(
          company: company,
          repository: repository,
          initialParentId: account.id,
          initialLevel: AccountLevel.values[account.level.index + 1],
        ),
      ),
    );
    if (saved != null && context.mounted) {
      context.read<ChartOfAccountsCubit>().load();
    }
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context)
        .push<AccountNode>(MaterialPageRoute<AccountNode>(
      builder: (_) => AccountFormPage(
          account: account, company: company, repository: repository),
    ));
    if (saved != null && context.mounted) {
      context.read<ChartOfAccountsCubit>().load();
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (company == null || repository == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('حذف سرفصل'),
              content: Text(account.children.isEmpty
                  ? 'سرفصل «${account.title}» حذف شود؟'
                  : 'این سرفصل زیرمجموعه دارد و تا حذف زیرمجموعه‌ها قابل حذف نیست.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('انصراف')),
                if (account.children.isEmpty)
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حذف')),
              ],
            ));
    if (confirmed != true || !context.mounted) return;
    try {
      await repository!.deleteAccount(company!, account);
      if (context.mounted) context.read<ChartOfAccountsCubit>().load();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'حذف سرفصل انجام نشد؛ گردش یا زیرمجموعه حساب را بررسی کنید.')),
        );
      }
    }
  }
}
