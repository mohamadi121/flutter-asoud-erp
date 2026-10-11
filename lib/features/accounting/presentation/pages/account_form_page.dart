import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/detail_group_repository.dart';
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
          lockHierarchy: account != null ||
              initialLevel != null ||
              initialParentId != null,
        ),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: _AccountFormView(
              contextual: account != null ||
                  initialLevel != null ||
                  initialParentId != null,
              accounts: repository == null || company == null
                  ? Future.value(const <AccountNode>[])
                  : repository!.getAccounts(company!),
            )),
      );
}

class _AccountFormView extends StatefulWidget {
  const _AccountFormView({required this.accounts, required this.contextual});
  final Future<List<AccountNode>> accounts;
  final bool contextual;

  @override
  State<_AccountFormView> createState() => _AccountFormViewState();
}

class _AccountFormViewState extends State<_AccountFormView> {
  Future<List<DetailGroup>>? groups;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    groups ??=
        RepositoryProvider.of<DetailGroupRepository?>(context)?.getGroups() ??
            Future.value(const <DetailGroup>[]);
  }

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
              subtitle: _levelTitle(state.level),
            ),
            body: SafeArea(
              child: FutureBuilder<List<AccountNode>>(
                future: widget.accounts,
                builder: (context, snapshot) {
                  final accounts = _flatten(snapshot.data ?? const []);
                  final parents = accounts
                      .where((item) =>
                          item.level == _parentLevel(state.level) &&
                          (state.level == AccountLevel.detail ||
                              !item.isTerminal))
                      .toList(growable: false);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    children: [
                      if (!widget.contextual &&
                          state.mode == AccountFormMode.create)
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
                            Text('اطلاعات ${_levelTitle(state.level)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            if (!widget.contextual) ...[
                              Text('سطح حساب *', style: _labelStyle),
                              const SizedBox(height: 5),
                              _ReadOnlyField(value: _levelTitle(state.level)),
                            ],
                            if (state.requiresParent && !widget.contextual) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: AppSelectField(
                                  label: '${_parentTitle(state.level)} والد',
                                  required: true,
                                  value: state.parentId ?? '',
                                  displayValue: _parentLabel(parents,
                                      state.parentId, state.level),
                                  hint: parents.isEmpty
                                      ? 'ابتدا ${_parentTitle(state.level)} را ایجاد کنید'
                                      : 'انتخاب ${_parentTitle(state.level)}',
                                  enabled: parents.isNotEmpty,
                                  onPick: parents.isEmpty
                                      ? null
                                      : () => showAppOptionSheet(context,
                                          title:
                                              '${_parentTitle(state.level)} والد',
                                          current: state.parentId,
                                          options: [
                                            for (final item in parents)
                                              AppOption(
                                                  item.id,
                                                  '${toPersianDigits(item.code)}  ${item.title}')
                                          ]),
                                  onChanged: cubit.setParent,
                                ),
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppSelectField(
                                label: 'ماهیت حساب',
                                required: true,
                                value: state.nature.name,
                                displayValue: _natureTitle(state.nature),
                                hint: 'ماهیت حساب را انتخاب کنید',
                                onPick: () => showAppOptionSheet(context,
                                    title: 'ماهیت حساب',
                                    current: state.nature.name,
                                    options: [
                                      for (final nature in AccountNature.values)
                                        AppOption(
                                            nature.name, _natureTitle(nature))
                                    ]),
                                onChanged: (value) => cubit.setNature(
                                    AccountNature.values.byName(value)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (state.level == AccountLevel.ledger) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: AppSelectField(
                                  label: 'نوع حساب',
                                  required: true,
                                  value: state.accountType,
                                  displayValue: _accountTypeTitle(
                                      state.accountType),
                                  hint: 'نوع حساب را انتخاب کنید',
                                  onPick: () => showAppOptionSheet(context,
                                      title: 'نوع حساب',
                                      current: state.accountType,
                                      options: const [
                                        AppOption('', 'عادی'),
                                        AppOption('Bank', 'بانک'),
                                        AppOption('Cash', 'صندوق'),
                                        AppOption(
                                            'Receivable', 'دریافتنی'),
                                        AppOption('Payable', 'پرداختنی'),
                                        AppOption(
                                            'Fixed Asset', 'دارایی ثابت'),
                                        AppOption(
                                            'Income Account', 'حساب درآمد'),
                                        AppOption(
                                            'Expense Account', 'حساب هزینه'),
                                      ]),
                                  onChanged: cubit.setAccountType,
                                ),
                              ),
                            ],
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
                      if (state.level != AccountLevel.detail)
                        FutureBuilder<List<DetailGroup>>(
                          future: groups,
                          builder: (context, groupSnapshot) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('گروه‌های تفصیلی شناور',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const Text(
                                        'با انتخاب گروه تفصیلی، این حساب در همین سطح نهایی می‌شود.'),
                                    if (groupSnapshot.connectionState ==
                                        ConnectionState.waiting)
                                      const LinearProgressIndicator(),
                                    if (groupSnapshot.hasError)
                                      TextButton(
                                          onPressed: () => setState(() {
                                                groups = context
                                                    .read<
                                                        DetailGroupRepository>()
                                                    .getGroups();
                                              }),
                                          child: const Text(
                                              'دریافت گروه‌ها ناموفق بود؛ تلاش دوباره')),
                                    const SizedBox(height: 12),
                                    GridView(
                                      key: const ValueKey(
                                          'detail-group-choices'),
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                              mainAxisExtent: 144),
                                      children: [
                                        for (final group
                                            in groupSnapshot.data ??
                                                const <DetailGroup>[])
                                          _DetailGroupChoice(
                                              group: group,
                                              selected: state.detailGroupIds
                                                  .contains(group.id.isEmpty
                                                      ? group.code
                                                      : group.id),
                                              onChanged: group.disabled ||
                                                      state.status ==
                                                          AccountFormStatus
                                                              .saving
                                                  ? null
                                                  : (value) =>
                                                      cubit.selectDetailGroup(
                                                          group.id.isEmpty
                                                              ? group.code
                                                              : group.id,
                                                          value)),
                                      ],
                                    ),
                                    for (final id in state.detailGroupIds.where(
                                        (id) => !(groupSnapshot.data ??
                                                const <DetailGroup>[])
                                            .any((g) =>
                                                (g.id.isEmpty
                                                    ? g.code
                                                    : g.id) ==
                                                id)))
                                      CheckboxListTile(
                                          title: Text(id),
                                          value: true,
                                          onChanged: state.status ==
                                                  AccountFormStatus.saving
                                              ? null
                                              : (_) => cubit.selectDetailGroup(
                                                  id, false)),
                                  ]),
                            ),
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

class _DetailGroupChoice extends StatelessWidget {
  const _DetailGroupChoice(
      {required this.group, required this.selected, this.onChanged});
  final DetailGroup group;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final role = (group.iconKey ?? group.partyRole ?? '').toLowerCase();
    final (icon, fallback) = switch (role) {
      'supplier' => (Icons.inventory_2_outlined, AsoudColors.success),
      'employee' => (Icons.badge_outlined, AsoudColors.warning),
      'cash' => (Icons.account_balance_wallet_outlined, AsoudColors.purple),
      'bank' => (Icons.account_balance_outlined, AsoudColors.cyan),
      'project' => (Icons.work_outline_rounded, AsoudColors.danger),
      _ => (Icons.people_outline_rounded, AsoudColors.primary),
    };
    final hex = group.colorHex?.replaceFirst('#', '');
    final parsed = hex == null ? null : int.tryParse(hex, radix: 16);
    final color = parsed == null
        ? fallback
        : Color(hex!.length == 6 ? 0xFF000000 | parsed : parsed);
    return Card(
      key:
          ValueKey('detail-choice-${group.id.isEmpty ? group.code : group.id}'),
      margin: EdgeInsets.zero,
      color: selected ? color.withValues(alpha: .08) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color : AsoudColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: color, size: 26),
                  const Spacer(),
                  Checkbox(
                      value: selected,
                      activeColor: color,
                      onChanged: onChanged == null
                          ? null
                          : (value) => onChanged!(value ?? false)),
                ]),
                Text(group.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
                Text(toPersianDigits(group.code),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 11, color: color)),
              ],
            )),
      ),
    );
  }
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
  Widget build(BuildContext context) => AppTextField(
        label: label.endsWith(' *')
            ? label.substring(0, label.length - 2)
            : label,
        required: label.endsWith(' *'),
        initialValue: initialValue,
        enabled: enabled,
        keyboardType: keyboardType,
        hint: hint,
        onChanged: onChanged,
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

String _parentLabel(List<AccountNode> parents, String? parentId, AccountLevel level) {
  for (final item in parents) {
    if (item.id == parentId) {
      return '${toPersianDigits(item.code)}  ${item.title}';
    }
  }
  return parentId ?? '';
}

String _natureTitle(AccountNature nature) => switch (nature) {
      AccountNature.debit => 'بدهکار',
      AccountNature.credit => 'بستانکار',
      AccountNature.both => 'بدهکار و بستانکار',
    };

String _accountTypeTitle(String type) => switch (type) {
      '' => 'عادی',
      'Bank' => 'بانک',
      'Cash' => 'صندوق',
      'Receivable' => 'دریافتنی',
      'Payable' => 'پرداختنی',
      'Fixed Asset' => 'دارایی ثابت',
      'Income Account' => 'حساب درآمد',
      'Expense Account' => 'حساب هزینه',
      _ => type,
    };

const _labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800);
