import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/entities/workflow_notification.dart';
import '../../domain/repositories/workflow_notification_repository.dart';
import '../cubit/workflow_notifications_cubit.dart';
import 'workflow_instance_detail_page.dart';

class WorkflowNotificationsPage extends StatelessWidget {
  const WorkflowNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkflowNotificationsCubit(
          context.read<WorkflowNotificationRepository>(),
        )..load(),
        child: const _View(),
      );
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'اعلان‌ها',
          subtitle: 'رویدادها و کارهای جدید گردش‌کار',
        ),
        body:
            BlocBuilder<WorkflowNotificationsCubit, WorkflowNotificationsState>(
                builder: (context, state) {
          if (state.status == WorkflowNotificationsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WorkflowNotificationsStatus.failure) {
            return ErrorState(
                failure: state.message ?? 'دریافت اعلان‌ها ممکن نشد.',
                onRetry: context.read<WorkflowNotificationsCubit>().load);
          }
          return RefreshIndicator(
            onRefresh: context.read<WorkflowNotificationsCubit>().load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (state.offline) const AsoudOfflinePreviewBanner(),
                AsoudSegmentedControl<bool>(
                  value: state.unreadOnly,
                  options: const [
                    AsoudSegmentedOption(value: false, label: 'همه'),
                    AsoudSegmentedOption(value: true, label: 'خوانده‌نشده'),
                  ],
                  onChanged: (value) => context
                      .read<WorkflowNotificationsCubit>()
                      .load(unreadOnly: value),
                ),
                const SizedBox(height: 12),
                if (state.items.isEmpty)
                  const _Empty()
                else
                  for (final item in state.items) _NotificationCard(item: item),
              ],
            ),
          );
        }),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final WorkflowNotification item;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await context.read<WorkflowNotificationsCubit>().markRead(item);
            if (context.mounted && item.instance.isNotEmpty) {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WorkflowInstanceDetailPage(
                    instance: item.instance,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AsoudIconBox(
                icon: item.isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: item.isRead ? AsoudColors.muted : AsoudColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(persianNotificationTitle(item.title),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AsoudColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                    if (item.message.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(item.message,
                          style: const TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      formatDateTimeJalali(item.createdAt),
                      style: const TextStyle(
                          fontSize: 9, color: AsoudColors.muted),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Column(children: [
          AsoudIconBox(
              icon: Icons.notifications_off_outlined,
              color: AsoudColors.warning,
              size: 52),
          SizedBox(height: 12),
          Text('اعلانی برای نمایش وجود ندارد.',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
