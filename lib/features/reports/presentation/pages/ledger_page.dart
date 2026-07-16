import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_reports_repository.dart';
import '../../domain/entities/ledger_report.dart';
import '../cubit/ledger_cubit.dart';
import '../cubit/trial_balance_cubit.dart';
import 'report_filters.dart';

class LedgerPage extends StatelessWidget {
  const LedgerPage({required this.title, this.allowParty = false, super.key});
  final String title;
  final bool allowParty;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => LedgerCubit(FrappeReportsRepository(FrappeClient())),
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: BlocBuilder<LedgerCubit, LedgerState>(builder: (context, state) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ReportFilters(
                requireAccount: true,
                allowParty: allowParty,
                onSubmit: (company, from, to, account, partyType, party) => context.read<LedgerCubit>().load(
                  company: company,
                  fromDate: from,
                  toDate: to,
                  account: account,
                  partyType: partyType,
                  party: party,
                ),
              ),
              const SizedBox(height: 14),
              if (state.status == ReportStatus.loading) const Center(child: CircularProgressIndicator()),
              if (state.status == ReportStatus.failure) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(state.message ?? 'دریافت گزارش ناموفق بود'))),
              if (state.report != null) _LedgerResult(report: state.report!),
            ],
          )),
        ),
      );
}

class _LedgerResult extends StatelessWidget {
  const _LedgerResult({required this.report});
  final LedgerReport report;
  @override
  Widget build(BuildContext context) => Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 22, runSpacing: 12, alignment: WrapAlignment.spaceAround, children: [
          _Metric(title: 'افتتاحیه', value: report.openingBalance),
          _Metric(title: 'بدهکار', value: report.totalDebit),
          _Metric(title: 'بستانکار', value: report.totalCredit),
          _Metric(title: 'مانده', value: report.closingBalance),
        ]))),
        const SizedBox(height: 8),
        if (report.entries.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('در این بازه گردش حسابی ثبت نشده است.'))),
        ...report.entries.map((entry) => Card(child: ListTile(
          title: Text(entry.description.isEmpty ? entry.voucherNo : entry.description, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${entry.date.toIso8601String().split('T').first} • ${entry.account}\n${entry.voucherType} ${entry.voucherNo}${entry.party.isEmpty ? '' : ' • ${entry.party}'}'),
          isThreeLine: true,
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(entry.debit > 0 ? 'بدهکار ${entry.debit.toStringAsFixed(0)}' : 'بستانکار ${entry.credit.toStringAsFixed(0)}'),
            Text('مانده ${entry.balance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ))),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value});
  final String title;
  final double value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(title, style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 4), Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800))]);
}
