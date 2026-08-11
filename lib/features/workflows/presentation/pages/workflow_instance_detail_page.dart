import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

class WorkflowInstanceDetailPage extends StatelessWidget {
  const WorkflowInstanceDetailPage({required this.instance, super.key});
  final String instance;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'پیگیری درخواست',
          subtitle: 'مرحله، مسئول فعلی و تاریخچه اقدامات',
        ),
        body: FutureBuilder<WorkflowInstanceDetail>(
          future: context.read<WorkflowTaskRepository>().getInstance(instance),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('دریافت اطلاعات پیگیری ممکن نشد.'));
            }
            final detail = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (detail.summary.localOnly) const AsoudOfflinePreviewBanner(),
                _InstanceStatusCard(item: detail.summary),
                const SizedBox(height: 16),
                const AsoudSectionTitle(title: 'تاریخچه گردش درخواست'),
                if (detail.activities.isEmpty)
                  const _EmptyTimeline()
                else
                  for (var i = 0; i < detail.activities.length; i++)
                    _TimelineItem(
                      activity: detail.activities[i],
                      last: i == detail.activities.length - 1,
                    ),
              ],
            );
          },
        ),
      );
}

class _InstanceStatusCard extends StatelessWidget {
  const _InstanceStatusCard({required this.item});
  final WorkflowInstanceSummary item;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.subject,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _row('وضعیت', _status(item.status)),
          _row(
              'مرحله فعلی',
              item.currentStageTitle.isEmpty
                  ? 'پایان‌یافته'
                  : item.currentStageTitle),
          _row(
              'مسئول فعلی',
              item.currentAssignees.isEmpty
                  ? 'بدون مسئول باز'
                  : item.currentAssignees.join('، ')),
          if (item.referenceName.isNotEmpty)
            _row('سند مرتبط',
                '${item.referenceDoctype} • ${item.referenceName}'),
        ]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.activity, required this.last});
  final WorkflowTaskActivity activity;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              const CircleAvatar(
                radius: 8,
                backgroundColor: AsoudColors.primary,
                child: Icon(Icons.check_rounded, size: 11, color: Colors.white),
              ),
              if (!last)
                Expanded(child: Container(width: 1, color: AsoudColors.border)),
            ]),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_action(activity.action),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(activity.actor,
                        style: const TextStyle(
                            fontSize: 9, color: AsoudColors.muted)),
                    if (activity.comment.isNotEmpty)
                      Text(activity.comment,
                          style: const TextStyle(fontSize: 10)),
                  ]),
            ),
          ),
        ]),
      );
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(18),
        child: Text('هنوز اقدامی برای این درخواست ثبت نشده است.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
      );
}

String _status(String value) => switch (value) {
      'Running' => 'در حال گردش',
      'Completed' => 'تکمیل‌شده',
      'Rejected' => 'ردشده',
      'Cancelled' => 'لغوشده',
      'Failed' => 'ناموفق',
      _ => value,
    };

String _action(String value) => switch (value) {
      'Complete' => 'مرحله تکمیل شد',
      'Approve' => 'تأیید شد',
      'Reject' => 'رد شد',
      'Return' => 'برای اصلاح بازگردانده شد',
      'Condition True' => 'شرط برقرار بود',
      'Condition False' => 'شرط برقرار نبود',
      _ => value,
    };
