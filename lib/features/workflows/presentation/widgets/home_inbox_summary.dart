import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../calendar/calendar_repository.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../pages/cartable_page.dart';

/// Aggregate of the existing office-scoped inbox, without a second task store.
class HomeInboxSummary extends StatefulWidget {
  const HomeInboxSummary(
      {this.repository, this.now, this.company = '', super.key});
  final WorkflowTaskRepository? repository;
  final DateTime? now;
  final String company;
  @override
  State<HomeInboxSummary> createState() => _HomeInboxSummaryState();
}

class _HomeInboxSummaryState extends State<HomeInboxSummary> {
  late Future<CalendarRow> future = _load();

  Future<CalendarRow> _load() async {
    if (widget.company.isEmpty) throw StateError('دفتر فعال مشخص نیست.');
    return CalendarRepository(context.read<FrappeApiClient?>(), widget.company)
        .actionCounts(widget.now ?? DateTime.now());
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => future = next);
    await next.catchError((Object _) => <String, dynamic>{});
  }

  Future<void> _open() async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CartablePage(company: widget.company)));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('نیازمند اقدام من',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: _open, child: const Text('کارتابل')),
                  ]),
                  FutureBuilder<CalendarRow>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('در حال دریافت آمار کارتابل…',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: AsoudColors.muted)),
                          );
                        }
                        if (snapshot.hasError) {
                          return TextButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(snapshot.error is StateError
                                  ? (snapshot.error as StateError)
                                      .message
                                      .toString()
                                  : failureMessage(snapshot.error!)));
                        }
                        final counts = snapshot.data!;
                        if (!['waiting', 'overdue', 'high_priority']
                            .every((key) => counts[key] is num)) {
                          return TextButton(
                              onPressed: _refresh,
                              child: const Text(
                                  'آمار کامل دریافت نشد؛ تلاش مجدد'));
                        }
                        return Row(children: [
                          for (final metric in const [
                            (
                              'در انتظار',
                              'waiting',
                              Color(0xFF2878DE),
                              Color(0xFFEAF3FF)
                            ),
                            (
                              'معوق',
                              'overdue',
                              AsoudColors.danger,
                              Color(0xFFFCE7EA)
                            ),
                            (
                              'اولویت بالا',
                              'high_priority',
                              Color(0xFF22966B),
                              Color(0xFFE3F5EB)
                            ),
                          ]) ...[
                            if (metric.$2 != 'waiting')
                              const SizedBox(width: 6),
                            Expanded(
                                child: Material(
                                    color: metric.$4,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                        onTap: _open,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 2),
                                            child: Column(children: [
                                              Text(
                                                  toPersianDigits(
                                                      counts[metric.$2]),
                                                  style: TextStyle(
                                                      color: metric.$3,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              const SizedBox(height: 4),
                                              Text(metric.$1,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AsoudColors.muted)),
                                            ]))))),
                          ],
                        ]);
                      }),
                ])),
      );
}
