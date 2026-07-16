import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_reports_repository.dart';
import '../../domain/entities/trial_balance.dart';
import '../cubit/trial_balance_cubit.dart';
import 'report_filters.dart';

class TrialBalancePage extends StatelessWidget {
  const TrialBalancePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => TrialBalanceCubit(FrappeReportsRepository(FrappeClient())),
        child: Scaffold(
          appBar: AppBar(title: const Text('تراز آزمایشی')),
          body: BlocBuilder<TrialBalanceCubit, TrialBalanceState>(builder: (context, state) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ReportFilters(
                requireAccount: false,
                onSubmit: (company, from, to, account, _, __) => context.read<TrialBalanceCubit>().load(company: company, fromDate: from, toDate: to, account: account),
              ),
              const SizedBox(height: 14),
              if (state.status == ReportStatus.loading) const Center(child: CircularProgressIndicator()),
              if (state.status == ReportStatus.failure) _MessageCard(message: state.message ?? 'دریافت گزارش ناموفق بود'),
              if (state.report != null) _TrialTable(report: state.report!),
            ],
          )),
        ),
      );
}

class _TrialTable extends StatelessWidget {
  const _TrialTable({required this.report});
  final TrialBalanceReport report;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(report.periodIsBalanced ? Icons.verified_rounded : Icons.warning_amber_rounded, color: report.periodIsBalanced ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            Text(report.periodIsBalanced ? 'گردش دوره تراز است' : 'گردش دوره نامتوازن است', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('حساب')),
                DataColumn(label: Text('افتتاحیه بدهکار'), numeric: true),
                DataColumn(label: Text('افتتاحیه بستانکار'), numeric: true),
                DataColumn(label: Text('گردش بدهکار'), numeric: true),
                DataColumn(label: Text('گردش بستانکار'), numeric: true),
                DataColumn(label: Text('مانده بدهکار'), numeric: true),
                DataColumn(label: Text('مانده بستانکار'), numeric: true),
              ],
              rows: [...report.rows, report.totals].map((row) => DataRow(cells: [
                DataCell(Text(row.account, style: row == report.totals ? const TextStyle(fontWeight: FontWeight.w800) : null)),
                ...[row.openingDebit, row.openingCredit, row.periodDebit, row.periodCredit, row.closingDebit, row.closingCredit].map((value) => DataCell(Text(value.toStringAsFixed(0)))),
              ])).toList(),
            ),
          ),
        ]),
      ));
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(message)));
}
