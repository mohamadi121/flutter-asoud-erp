import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_chart_of_accounts_repository.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import '../cubit/chart_of_accounts_cubit.dart';
import 'account_form_page.dart';

class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = FrappeChartOfAccountsRepository(
      FrappeClient(),
      company: AppConfig.companyName,
    );
    return BlocProvider(
      create: (_) => ChartOfAccountsCubit(repository)..load(),
      child: _ChartOfAccountsView(repository: repository),
    );
  }
}

class _ChartOfAccountsView extends StatelessWidget {
  const _ChartOfAccountsView({required this.repository});
  final ChartOfAccountsRepository repository;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChartOfAccountsCubit>().state;
    return Scaffold(
        appBar: AppBar(title: const Text('سرفصل حساب‌ها')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final saved = await Navigator.of(context).push<AccountNode>(
              MaterialPageRoute<AccountNode>(
                builder: (_) => AccountFormPage(
                  repository: repository,
                  accounts: state.accounts,
                ),
              ),
            );
            if (saved != null && context.mounted) {
              await context.read<ChartOfAccountsCubit>().load();
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('سرفصل جدید'),
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
            TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'جست‌وجوی کد یا عنوان حساب', suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list_rounded)))),
            const SizedBox(height: 14),
            if (state.status == ChartStatus.loading)
              const Center(child: CircularProgressIndicator())
            else if (state.status == ChartStatus.failure)
              _LoadFailure(message: state.message)
            else if (state.accounts.isEmpty)
              const Center(child: Text('هنوز سرفصل حسابی ثبت نشده است.'))
            else
              ...state.accounts.map(
                (account) => _AccountTile(
                  account: account,
                  repository: repository,
                  accounts: state.accounts,
                ),
              ),
          ]),
        ),
      );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.repository,
    required this.accounts,
  });
  final AccountNode account;
  final ChartOfAccountsRepository repository;
  final List<AccountNode> accounts;
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
          children: account.children
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AccountTile(
                    account: child,
                    repository: repository,
                    accounts: accounts,
                  ),
                ),
              )
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
              builder: (_) => AccountFormPage(
                repository: repository,
                accounts: accounts,
                account: account,
              ),
            ),
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

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('دریافت سرفصل‌ها از ERPNext انجام نشد.'),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message!, textAlign: TextAlign.center),
            ),
          TextButton(
            onPressed: context.read<ChartOfAccountsCubit>().load,
            child: const Text('تلاش دوباره'),
          ),
        ],
      );
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
