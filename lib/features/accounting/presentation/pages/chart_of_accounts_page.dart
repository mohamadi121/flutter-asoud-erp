import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
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

class _ChartOfAccountsView extends StatelessWidget {
  const _ChartOfAccountsView();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سرفصل حساب‌ها')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<AccountNode>(builder: (_) => const AccountFormPage()),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('سرفصل جدید'),
        ),
        body: SafeArea(child: BlocBuilder<ChartOfAccountsCubit, ChartOfAccountsState>(builder: (context, state) {
          return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
            TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'جست‌وجوی کد یا عنوان حساب', suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list_rounded)))),
            const SizedBox(height: 14),
            ...state.accounts.map((account) => _AccountTile(account: account)),
          ]);
        })),
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
          title: Text(account.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_levelTitle(account.level)),
          children: account.children.map((child) => Padding(padding: const EdgeInsets.only(right: 12), child: _AccountTile(account: child))).toList(),
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
            MaterialPageRoute<AccountNode>(builder: (_) => AccountFormPage(account: account)),
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
        decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(10)),
        child: Text(code, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      );
}
