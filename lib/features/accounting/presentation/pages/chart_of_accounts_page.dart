import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../cubit/chart_of_accounts_cubit.dart';
import 'account_form_page.dart';

class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ChartOfAccountsCubit()..load(),
        child: const _ChartOfAccountsView(),
      );
}

class _ChartOfAccountsView extends StatefulWidget {
  const _ChartOfAccountsView();
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
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<AccountNode>(
                builder: (_) => const AccountFormPage()),
          ),
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
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.account_tree_outlined),
                        label: Text('نمای درختی')),
                    ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('نمای مرحله‌ای')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
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
                  ...visible.map((account) => _AccountTile(account: account)),
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
  const _AccountTile({required this.account});
  final AccountNode account;
  @override
  Widget build(BuildContext context) {
    final hasChildren = account.children.isNotEmpty;
    final color = _levelColor(account.level);
    if (hasChildren) {
      return Card(
        elevation: 0,
        color: Colors.white,
        child: ExpansionTile(
          leading: _CodeBadge(code: account.code, color: color),
          title: Text(account.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_levelTitle(account.level)),
          children: account.children
              .map((child) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AccountTile(account: child)))
              .toList(),
        ),
      );
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: _CodeBadge(code: account.code, color: color),
        title: Text(account.title),
        subtitle: Text(_levelTitle(account.level)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<AccountNode>(
                builder: (_) => AccountFormPage(account: account)),
          ),
        ),
      ),
    );
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
