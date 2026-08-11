import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import '../cubit/account_form_cubit.dart';

class AccountFormPage extends StatelessWidget {
  const AccountFormPage({
    this.account,
    this.company,
    this.repository,
    this.initialLevel,
    this.initialParentId,
    super.key,
  });

  final AccountNode? account;
  final String? company;
  final ChartOfAccountsRepository? repository;
  final AccountLevel? initialLevel;
  final String? initialParentId;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AccountFormCubit(
          account: account,
          company: company,
          repository: repository,
          initialLevel: initialLevel,
          initialParentId: initialParentId,
        ),
        child: _AccountFormView(
          accounts: repository == null || company == null
              ? Future.value(const <AccountNode>[])
              : repository!.getAccounts(company!),
        ),
      );
}

class _AccountFormView extends StatefulWidget {
  const _AccountFormView({required this.accounts});
  final Future<List<AccountNode>> accounts;

  @override
  State<_AccountFormView> createState() => _AccountFormViewState();
}

class _AccountFormViewState extends State<_AccountFormView> {
  bool stagedView = true;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<AccountFormCubit, AccountFormState>(
        listenWhen: (before, after) => before.status != after.status,
        listener: (context, state) {
          if (state.status == AccountFormStatus.success ||
              state.status == AccountFormStatus.offlineSaved) {
            Navigator.of(context).pop(state.savedAccount ?? state.toEntity());
          }
        },
        builder: (context, state) {
          final cubit = context.read<AccountFormCubit>();
          return Scaffold(
            appBar: AsoudHeader(
              title: state.mode == AccountFormMode.create
                  ? 'تکمیل اطلاعات حساب'
                  : 'ویرایش اطلاعات حساب',
              subtitle: 'ایجاد یا ویرایش حساب کل و معین',
            ),
            body: SafeArea(
              child: FutureBuilder<List<AccountNode>>(
                future: widget.accounts,
                builder: (context, snapshot) {
                  final accounts = _flatten(snapshot.data ?? const []);
                  final parents = accounts
                      .where((item) => item.level == _parentLevel(state.level))
                      .toList(growable: false);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    children: [
                      _ViewSelector(
                        staged: stagedView,
                        onChanged: (value) =>
                            setState(() => stagedView = value),
                      ),
                      const SizedBox(height: 28),
                      _LevelSelector(
                          value: state.level, onChanged: cubit.setLevel),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AsoudColors.border),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('اطلاعات اصلی سرفصل',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            Text('سطح حساب *', style: _labelStyle),
                            const SizedBox(height: 5),
                            _ReadOnlyField(value: _levelTitle(state.level)),
                            if (state.requiresParent) ...[
                              const SizedBox(height: 10),
                              Text('${_parentTitle(state.level)} والد *',
                                  style: _labelStyle),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                    '${state.level}-${parents.length}'),
                                isExpanded: true,
                                initialValue:
                                    parents.any((e) => e.id == state.parentId)
                                        ? state.parentId
                                        : null,
                                hint: Text(parents.isEmpty
                                    ? 'ابتدا ${_parentTitle(state.level)} را ایجاد کنید'
                                    : 'انتخاب ${_parentTitle(state.level)}'),
                                items: parents
                                    .map((item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Text(
                                              '${item.code}  ${item.title}'),
                                        ))
                                    .toList(),
                                onChanged:
                                    parents.isEmpty ? null : cubit.setParent,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                flex: 2,
                                child: _LabeledTextField(
                                  label: 'نام حساب *',
                                  initialValue: state.title,
                                  onChanged: cubit.setTitle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LabeledTextField(
                                  label: 'کد حساب *',
                                  initialValue: state.code,
                                  enabled: !state.autoCode,
                                  keyboardType: TextInputType.number,
                                  hint: state.autoCode ? 'خودکار' : null,
                                  onChanged: cubit.setCode,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text('ماهیت حساب *', style: _labelStyle),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<AccountNature>(
                              isExpanded: true,
                              initialValue: state.nature,
                              items: const [
                                DropdownMenuItem(
                                    value: AccountNature.debit,
                                    child: Text('بدهکار')),
                                DropdownMenuItem(
                                    value: AccountNature.credit,
                                    child: Text('بستانکار')),
                                DropdownMenuItem(
                                    value: AccountNature.both,
                                    child: Text('بدهکار و بستانکار')),
                              ],
                              onChanged: (value) =>
                                  value == null ? null : cubit.setNature(value),
                            ),
                            const SizedBox(height: 10),
                            Text('نوع حساب *', style: _labelStyle),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: state.accountType,
                              items: const [
                                DropdownMenuItem(
                                    value: '', child: Text('عادی')),
                                DropdownMenuItem(
                                    value: 'Bank', child: Text('بانک')),
                                DropdownMenuItem(
                                    value: 'Cash', child: Text('صندوق')),
                                DropdownMenuItem(
                                    value: 'Receivable',
                                    child: Text('دریافتنی')),
                                DropdownMenuItem(
                                    value: 'Payable', child: Text('پرداختنی')),
                                DropdownMenuItem(
                                    value: 'Fixed Asset',
                                    child: Text('دارایی ثابت')),
                                DropdownMenuItem(
                                    value: 'Income Account',
                                    child: Text('حساب درآمد')),
                                DropdownMenuItem(
                                    value: 'Expense Account',
                                    child: Text('حساب هزینه')),
                              ],
                              onChanged: (value) => value == null
                                  ? null
                                  : cubit.setAccountType(value),
                            ),
                            const SizedBox(height: 12),
                            _RecommendationSwitch(
                              autoCode: state.autoCode,
                              active: state.isActive,
                              onAutoCode: cubit.setAutoCode,
                              onActive: cubit.setActive,
                            ),
                            if (state.status == AccountFormStatus.invalid)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                    'نام حساب، حساب والد و کد حساب را بررسی کنید.',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 10)),
                              ),
                            if (state.status == AccountFormStatus.failure)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                    state.message ?? 'ذخیره حساب انجام نشد.',
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 10)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            bottomNavigationBar: AsoudBottomActions(
              primaryLabel: state.status == AccountFormStatus.saving
                  ? 'در حال ذخیره...'
                  : 'ذخیره حساب',
              onPrimary: state.status == AccountFormStatus.saving
                  ? null
                  : cubit.submit,
              secondaryLabel: 'انصراف',
              onSecondary: () => Navigator.of(context).pop(),
            ),
          );
        },
      );

  static List<AccountNode> _flatten(List<AccountNode> source) => [
        for (final item in source) ...[item, ..._flatten(item.children)]
      ];

  static AccountLevel? _parentLevel(AccountLevel level) => switch (level) {
        AccountLevel.general => AccountLevel.group,
        AccountLevel.ledger => AccountLevel.general,
        _ => null,
      };

  static String _parentTitle(AccountLevel level) =>
      level == AccountLevel.ledger ? 'حساب کل' : 'گروه حساب';
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.staged, required this.onChanged});
  final bool staged;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          for (final item in const [
            (true, 'نمای مرحله‌ای'),
            (false, 'نمای درختی')
          ])
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        staged == item.$1 ? AsoudColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item.$2,
                      style: TextStyle(
                        color: staged == item.$1
                            ? Colors.white
                            : AsoudColors.muted,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
            ),
        ]),
      );
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.value, required this.onChanged});
  final AccountLevel value;
  final ValueChanged<AccountLevel> onChanged;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final item in const [
            (
              AccountLevel.group,
              'گروه',
              Icons.list_alt_rounded,
              Color(0xFFFFB547)
            ),
            (AccountLevel.general, 'کل', Icons.stop_rounded, Color(0xFF21A45D)),
            (
              AccountLevel.ledger,
              'معین',
              Icons.stop_rounded,
              Color(0xFF5B8DEF)
            ),
          ]) ...[
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  height: 42,
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: value == item.$1
                        ? item.$4.withValues(alpha: .13)
                        : Colors.white,
                    border: Border.all(color: AsoudColors.primary),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$3, size: 20, color: item.$4),
                        const SizedBox(width: 7),
                        Text(item.$2,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                ),
              ),
            ),
            if (item.$1 != AccountLevel.ledger) const SizedBox(width: 3),
          ],
        ],
      );
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFE),
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
    this.keyboardType,
    this.hint,
  });
  final String label, initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? hint;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 5),
          TextFormField(
            initialValue: initialValue,
            enabled: enabled,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
            onChanged: onChanged,
          ),
        ],
      );
}

class _RecommendationSwitch extends StatelessWidget {
  const _RecommendationSwitch({
    required this.autoCode,
    required this.active,
    required this.onAutoCode,
    required this.onActive,
  });
  final bool autoCode, active;
  final ValueChanged<bool> onAutoCode, onActive;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Row(children: [
            Switch(value: autoCode, onChanged: onAutoCode),
            const Expanded(
              child: Text('قانون کدگذاری پیشنهادی',
                  style: TextStyle(
                      color: AsoudColors.primary, fontWeight: FontWeight.w900)),
            ),
            Switch(value: active, onChanged: onActive),
            const Text('فعال باشد',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const Text('گروه: ۱ رقمی • کل: ۲ رقمی • معین: ۳ رقمی',
              style: TextStyle(fontSize: 8, color: AsoudColors.muted)),
        ]),
      );
}

String _levelTitle(AccountLevel level) => switch (level) {
      AccountLevel.group => 'سرفصل گروه حساب',
      AccountLevel.general => 'سرفصل حساب کل',
      AccountLevel.ledger => 'سرفصل حساب معین',
      AccountLevel.detail => 'تفصیلی شناور',
    };

const _labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800);
