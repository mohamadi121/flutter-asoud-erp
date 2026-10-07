import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../workflows/domain/entities/request_models.dart';
import '../../../workflows/presentation/widgets/request_status.dart';

Widget _meta(IconData icon, String text, {Color? color}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color ?? AsoudColors.muted),
      const SizedBox(width: 4),
      Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 11, color: color ?? AsoudColors.muted))),
    ]);

/// The frame all template cards share: number and status chip on the first
/// line, the [title], then [body]; a chevron marks it as tappable.
class _CardFrame extends StatelessWidget {
  const _CardFrame(
      {required this.summary, required this.title, required this.body});
  final RequestSummary summary;
  final String title;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text(summary.number,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                      const Spacer(),
                      RequestStatusChip(summary.raw),
                    ]),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    ...body,
                    if (summary.pendingSync &&
                        '${summary.raw['error'] ?? ''}'.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${summary.raw['error']}',
                              style: const TextStyle(
                                  fontSize: 11, color: AsoudColors.danger))),
                  ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: AsoudColors.muted),
          ]),
        ),
      );
}

String _text(Object? value) => '${value ?? ''}';

/// List card of a purchase or supply request: number, status, title, Jalali
/// date, requester, unit and project, and the item / attachment counts.
class ProcurementRequestCard extends StatelessWidget {
  const ProcurementRequestCard({required this.summary, super.key});
  final RequestSummary summary;

  @override
  Widget build(BuildContext context) {
    final info = summary.summary;
    final unit = [_text(info['org_unit_label']), _text(info['project_label'])]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    final method = _text(info['supply_method_label']);
    return _CardFrame(
      summary: summary,
      title: summary.subject,
      body: [
        if (summary.creation.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(formatJalaliIso(summary.creation),
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted))),
        if (summary.requesterName.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child:
                  _meta(Icons.person_outline_rounded, summary.requesterName)),
        if (unit.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _meta(Icons.folder_outlined, unit)),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _meta(Icons.attach_file_rounded,
              toPersianDigits(summary.attachmentCount)),
          _meta(Icons.inventory_2_outlined,
              '${toPersianDigits(summary.itemCount)} قلم'),
          if (method.isNotEmpty) _meta(Icons.local_shipping_outlined, method),
        ]),
      ],
    );
  }
}

/// List card of a leave request: number, status, title, the Jalali date (range),
/// duration and location, or the rejection reason of a rejected one.
class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({required this.summary, super.key});
  final RequestSummary summary;

  static String dateRange(Map<String, dynamic> info) {
    final from = _text(info['from_date']), to = _text(info['to_date']);
    if (from.isEmpty) return '';
    if (to.isEmpty || to == from) return formatJalaliIso(from);
    return 'از ${formatJalaliIso(from)} تا ${formatJalaliIso(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final info = summary.summary;
    final duration = LeaveDuration.fromMap(info['duration']).label;
    final location = _text(info['location_label']);
    final reason = summary.statusKey == RequestStatusKey.rejected
        ? _text(info['rejection_reason'])
        : '';
    final hourly = info['request_kind'] == 'Hourly';
    final title = summary.subject.isNotEmpty
        ? summary.subject
        : hourly
            ? 'درخواست مرخصی (ساعتی)'
            : 'درخواست مرخصی (روزانه)';
    final range = dateRange(info);
    return _CardFrame(
      summary: summary,
      title: title,
      body: [
        if (range.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(range,
                  key: const ValueKey('leave-card-dates'),
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted))),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          if (duration.isNotEmpty)
            _meta(
                hourly ? Icons.schedule_rounded : Icons.calendar_today_outlined,
                duration),
          if (location.isNotEmpty) _meta(Icons.location_on_outlined, location),
        ]),
        if (reason.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(reason,
                  key: const ValueKey('leave-card-rejection'),
                  style: const TextStyle(
                      fontSize: 11, color: AsoudColors.danger))),
      ],
    );
  }
}
