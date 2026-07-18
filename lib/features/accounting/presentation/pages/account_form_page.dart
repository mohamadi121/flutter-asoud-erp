import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import '../cubit/account_form_cubit.dart';

class AccountFormPage extends StatelessWidget {
  const AccountFormPage(
      {this.account, this.company, this.repository, super.key});
  final AccountNode? account;
  final String? company;
  final ChartOfAccountsRepository? repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AccountFormCubit(
          account: account,
          company: company,
          repository: repository,
        ),
        child: const _AccountFormView(),
      );
}

class _AccountFormView extends StatelessWidget {
  const _AccountFormView();

  static const parents = <AccountLevel, List<(String, String)>>{};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountFormCubit, AccountFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AccountFormStatus.success) {
          Navigator.of(context).pop(state.savedAccount ?? state.toEntity());
        }
      },
      builder: (context, state) {
        final cubit = context.read<AccountFormCubit>();
        final parentItems = parents[state.level] ?? const <(String, String)>[];
        return Scaffold(
          appBar: AsoudHeader(
              title: state.mode == AccountFormMode.create
                  ? 'تکمیل اطلاعات حساب'
                  : 'ویرایش اطلاعات حساب',
              subtitle: 'ایجاد و ویرایش سرفصل حسابداری'),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                DropdownButtonFormField<AccountLevel>(
                  isExpanded: true,
                  initialValue: state.level,
                  decoration: const InputDecoration(labelText: 'سطح حساب *'),
                  items: const [
                    DropdownMenuItem(
                        value: AccountLevel.group, child: Text('گروه')),
                    DropdownMenuItem(
                        value: AccountLevel.general, child: Text('کل')),
                    DropdownMenuItem(
                        value: AccountLevel.ledger, child: Text('معین')),
                    DropdownMenuItem(
                        value: AccountLevel.detail, child: Text('تفصیلی')),
                  ],
                  onChanged: (value) {
                    if (value != null) cubit.setLevel(value);
                  },
                ),
                const SizedBox(height: 14),
                if (state.requiresParent)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(state.level),
                    initialValue:
                        parentItems.any((item) => item.$1 == state.parentId)
                            ? state.parentId
                            : null,
                    decoration: InputDecoration(
                        labelText: '${_parentLevelTitle(state.level)} والد *'),
                    items: parentItems
                        .map((item) => DropdownMenuItem(
                            value: item.$1,
                            child: Text('${item.$1} — ${item.$2}')))
                        .toList(),
                    onChanged: cubit.setParent,
                  ),
                if (state.requiresParent) const SizedBox(height: 14),
                TextFormField(
                  initialValue: state.title,
                  decoration: const InputDecoration(labelText: 'عنوان حساب *'),
                  onChanged: cubit.setTitle,
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تولید خودکار کد'),
                  subtitle: Text(state.level == AccountLevel.detail
                      ? 'کد تفصیلی بر اساس الگو و حساب معین والد ساخته می‌شود.'
                      : 'Backend بر اساس الگوی تعریف‌شده و کد والد، اولین کد آزاد را می‌سازد.'),
                  value: state.autoCode,
                  onChanged: cubit.setAutoCode,
                ),
                if (!state.autoCode)
                  TextFormField(
                    initialValue: state.code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'کد حساب *'),
                    onChanged: cubit.setCode,
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AccountNature>(
                  isExpanded: true,
                  initialValue: state.nature,
                  decoration: const InputDecoration(labelText: 'ماهیت حساب'),
                  items: const [
                    DropdownMenuItem(
                        value: AccountNature.debit, child: Text('بدهکار')),
                    DropdownMenuItem(
                        value: AccountNature.credit, child: Text('بستانکار')),
                    DropdownMenuItem(
                        value: AccountNature.both,
                        child: Text('بدهکار و بستانکار')),
                  ],
                  onChanged: (value) {
                    if (value != null) cubit.setNature(value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('حساب فعال باشد'),
                    value: state.isActive,
                    onChanged: cubit.setActive),
                if (state.level == AccountLevel.detail)
                  const _FloatingDetailHelp(),
                if (state.status == AccountFormStatus.invalid)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('عنوان، حساب والد و کد حساب را بررسی کنید.',
                        style: TextStyle(color: Colors.red)),
                  ),
                if (state.status == AccountFormStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(state.message ?? 'ذخیره حساب انجام نشد.',
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 22),
              ],
            ),
          ),
          bottomNavigationBar: AsoudBottomActions(
            primaryLabel: state.mode == AccountFormMode.create
                ? 'ذخیره حساب'
                : 'ذخیره تغییرات',
            onPrimary:
                state.status == AccountFormStatus.saving ? null : cubit.submit,
            secondaryLabel: 'انصراف',
            onSecondary: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  static String _parentLevelTitle(AccountLevel level) => switch (level) {
        AccountLevel.general => 'گروه',
        AccountLevel.ledger => 'حساب کل',
        AccountLevel.detail => 'حساب معین',
        AccountLevel.group => '',
      };
}

class _FloatingDetailHelp extends StatelessWidget {
  const _FloatingDetailHelp();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AsoudColors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14)),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: AsoudColors.primary),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'تفصیلی شناور به اشخاص، بانک‌ها، مراکز هزینه یا پروژه‌ها متصل می‌شود و می‌تواند زیر چند حساب معین استفاده شود. این راهنما بخشی از فرم است و جریان اجباری جداگانه ندارد.')),
        ]),
      );
}
