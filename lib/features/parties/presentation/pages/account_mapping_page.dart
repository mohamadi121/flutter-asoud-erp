import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../accounting/data/repositories/frappe_chart_of_accounts_repository.dart';
import '../../data/repositories/frappe_parties_repository.dart';
import '../cubit/account_mapping_cubit.dart';

class AccountMappingPage extends StatelessWidget {
  const AccountMappingPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AccountMappingCubit(
          FrappePartiesRepository(FrappeClient()),
          FrappeChartOfAccountsRepository(FrappeClient(), company: AppConfig.companyName),
          AppConfig.companyName,
        )..load(),
        child: const _AccountMappingView(),
      );
}

class _AccountMappingView extends StatelessWidget {
  const _AccountMappingView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AccountMappingCubit>().state;
    final cubit = context.read<AccountMappingCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('اتصال معین به گروه تفصیلی')),
      body: state.status == AccountMappingStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: state.accountId,
                  decoration: const InputDecoration(labelText: 'حساب معین *'),
                  items: state.accounts
                      .map((account) => DropdownMenuItem(value: account.id, child: Text('${account.code} — ${account.title}')))
                      .toList(),
                  onChanged: cubit.setAccount,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: state.groupCode,
                  decoration: const InputDecoration(labelText: 'گروه تفصیلی *'),
                  items: state.groups
                      .map((group) => DropdownMenuItem(value: group.code, child: Text('${group.code} — ${group.title}')))
                      .toList(),
                  onChanged: cubit.setGroup,
                ),
                if (state.status == AccountMappingStatus.invalid)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('حساب معین و گروه تفصیلی را انتخاب کنید.', style: TextStyle(color: Colors.red)),
                  ),
                if (state.status == AccountMappingStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(state.message ?? 'عملیات انجام نشد.', style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: state.status == AccountMappingStatus.saving ? null : cubit.submit,
                  child: const Text('ثبت اتصال'),
                ),
                const SizedBox(height: 24),
                const Text('اتصال‌های فعال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ...state.mappings.map(
                  (mapping) => ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: Text(mapping.accountId),
                    subtitle: Text('گروه ${mapping.groupCode}'),
                  ),
                ),
              ],
            ),
    );
  }
}
