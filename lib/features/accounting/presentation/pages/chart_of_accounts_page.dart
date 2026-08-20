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
        child: _ChartOfAccountsView(company: company, repository: repository),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'سرفصل‌های حسابداری',
            subtitle: 'ساختار گروه، کل، معین و تفصیلی'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final saved = await Navigator.of(context).push<AccountNode>(
              MaterialPageRoute<AccountNode>(
                  builder: (_) => AccountFormPage(
                        company: widget.company,
                        repository: widget.repository,
                      )),
            );
            if (saved != null && context.mounted) {
              context.read<ChartOfAccountsCubit>().load();
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('سرفصل جدید'),
        ),
        body: SafeArea(child:
            BlocBuilder<ChartOfAccountsCubit, ChartOfAccountsState>(
                builder: (context, state) {
          final filtered = _filterTree(state.accounts);
          final visible = _view == 0 ? filtered : _flatten(filtered);
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
                  onChanged: (value) => setState(() => _view = value),
                ),
                const SizedBox(height: 12),
                TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'جست‌وجوی کد یا عنوان حساب',
                        suffixIcon: IconButton(
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
                if (visible.isEmpty)
                  const _EmptyAccounts()
                else
                  ...visible.map((account) => _AccountTile(
                        account: account,
                        company: widget.company,
                        repository: widget.repository,
                      )),
              ]);
        })),
      );

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
                children: children,
              )
            : null;
      })
      .whereType<AccountNode>()
      .toList(growable: false);

  List<AccountNode> _flatten(List<AccountNode> accounts) => [
        for (final account in accounts) ...[
          AccountNode(
            id: account.id,
            code: account.code,
            title: account.title,
            level: account.level,
            parentId: account.parentId,
            isActive: account.isActive,
            nature: account.nature,
            accountType: account.accountType,
          ),
          ..._flatten(account.children),
        ],
      ];

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
      AccountLevel.general => 10.0,
      AccountLevel.ledger => 20.0,
      AccountLevel.detail => 30.0,
    };
    final tileHeight = switch (account.level) {
      AccountLevel.group => 86.0,
      AccountLevel.general => 78.0,
      AccountLevel.ledger => 70.0,
      AccountLevel.detail => 62.0,
    };
    if (hasChildren) {
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: Card(
            elevation: 0,
            color: Colors.white,
            child: ExpansionTile(
              minTileHeight: tileHeight,
              leading: _CodeBadge(code: account.code, color: color),
              title: Text(account.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_levelTitle(account.level)),
              trailing: _AccountMenu(
                  account: account, company: company, repository: repository),
              children: account.children
                  .map((child) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _AccountTile(
                        account: child,
                        company: company,
                        repository: repository,
                      )))
                  .toList(),
            ),
          ));
    }
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: Card(
          elevation: 0,
          color: Colors.white,
          child: SizedBox(
              height: tileHeight,
              child: ListTile(
                leading: _CodeBadge(code: account.code, color: color),
                title: Text(account.title),
                subtitle: Text(_levelTitle(account.level)),
                trailing: _AccountMenu(
                    account: account, company: company, repository: repository),
              )),
        ));
  }

  Color _levelColor(AccountLevel level) => switch (level) {
        AccountLevel.group => AsoudColors.primary,
        AccountLevel.general => const Color(0xFF26A69A),
        AccountLevel.ledger => const Color(0xFFFFB547),
        AccountLevel.detail => const Color(0xFFEF6C5B),
      };

  String _levelTitle(AccountLevel level) => switch (level) {
        AccountLevel.group => 'گروه',
        AccountLevel.general => 'کل',
        AccountLevel.ledger => 'معین',
        AccountLevel.detail => 'تفصیلی',
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
        onSelected: (value) =>
            value == 'edit' ? _edit(context) : _delete(context),
        itemBuilder: (_) => const [
          PopupMenuItem(
              value: 'edit',
              child: ListTile(
                  leading: Icon(Icons.edit_outlined), title: Text('ویرایش'))),
          PopupMenuItem(
              value: 'delete',
              child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('حذف', style: TextStyle(color: Colors.red)))),
        ],
      );

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

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code, required this.color});
  final String code;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(10)),
        child: Text(code,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      );
}
