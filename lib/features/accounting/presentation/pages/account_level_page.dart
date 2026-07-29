import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import 'account_form_page.dart';

class AccountLevelPage extends StatefulWidget {
  const AccountLevelPage(
      {required this.parent,
      required this.company,
      required this.repository,
      super.key});
  final AccountNode parent;
  final String company;
  final ChartOfAccountsRepository repository;
  @override
  State<AccountLevelPage> createState() => _AccountLevelPageState();
}

class _AccountLevelPageState extends State<AccountLevelPage> {
  int view = 1;
  AccountLevel get childLevel => widget.parent.level == AccountLevel.group
      ? AccountLevel.general
      : AccountLevel.ledger;
  String get levelTitle =>
      childLevel == AccountLevel.general ? 'سرفصل کل' : 'سرفصل معین';
  String get listTitle =>
      childLevel == AccountLevel.general ? 'حساب‌های کل' : 'حساب‌های معین';

  Future<void> openForm([AccountNode? account]) async {
    final saved =
        await Navigator.of(context).push<AccountNode>(MaterialPageRoute(
      builder: (_) => AccountFormPage(
        account: account,
        company: widget.company,
        repository: widget.repository,
        initialLevel: childLevel,
        initialParentId: widget.parent.id,
      ),
    ));
    if (saved != null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: levelTitle, subtitle: 'زیرمجموعه ${widget.parent.title}'),
        body: SafeArea(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            AsoudSegmentedControl<int>(
              value: view,
              options: const [
                AsoudSegmentedOption(value: 1, label: 'نمای مرحله‌ای'),
                AsoudSegmentedOption(value: 0, label: 'نمای درختی'),
              ],
              onChanged: (value) => setState(() => view = value),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                  color: AsoudColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13)),
              child: Text(
                  '${widget.parent.level == AccountLevel.group ? 'گروه' : 'حساب کل'}: ${widget.parent.code} - ${widget.parent.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AsoudColors.primary, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: AsoudColors.border),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listTitle,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        Text('زیرمجموعه ${widget.parent.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 8, color: AsoudColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                      onPressed: openForm,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('افزودن'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 38))),
                ]),
                const SizedBox(height: 6),
                Text(
                    childLevel == AccountLevel.general
                        ? 'الگو: کد گروه + کد حساب کل'
                        : 'الگو: کد کل + کد حساب معین',
                    style: const TextStyle(
                        fontSize: 8, color: AsoudColors.primary)),
                const SizedBox(height: 8),
                if (widget.parent.children.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('هنوز حسابی در این سطح ثبت نشده است.'))
                else
                  for (final account in widget.parent.children)
                    _LevelAccountCard(
                      account: account,
                      onEdit: () => openForm(account),
                      onTap: () => account.level == AccountLevel.general
                          ? Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => AccountLevelPage(
                                  parent: account,
                                  company: widget.company,
                                  repository: widget.repository)))
                          : openForm(account),
                    ),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E4),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text(
                        'کد حساب توسط Backend و براساس الگوی دفتر تولید می‌شود.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9, color: AsoudColors.warning))),
              ]),
            ),
          ],
        )),
        bottomNavigationBar: AsoudBottomActions(
            primaryLabel: 'ذخیره حساب',
            onPrimary: () => Navigator.of(context).pop(true),
            secondaryLabel: 'انصراف',
            onSecondary: () => Navigator.of(context).pop()),
      );
}

class _LevelAccountCard extends StatelessWidget {
  const _LevelAccountCard(
      {required this.account, required this.onTap, required this.onEdit});
  final AccountNode account;
  final VoidCallback onTap, onEdit;
  @override
  Widget build(BuildContext context) => Card(
          child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: AsoudColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(account.code,
                      style: const TextStyle(
                          color: AsoudColors.primary, fontSize: 9))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(account.title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                        account.accountType.isEmpty
                            ? 'حساب عادی'
                            : account.accountType,
                        style: const TextStyle(
                            fontSize: 8, color: AsoudColors.muted)),
                  ])),
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19)),
              const Icon(Icons.chevron_left_rounded,
                  color: AsoudColors.success),
            ])),
      ));
}
