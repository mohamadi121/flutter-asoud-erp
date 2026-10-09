import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/presentation/widgets/request_detail_scaffold.dart';

/// One icon + label + value row of a template's info card (mockup).
class InfoRowData {
  const InfoRowData(this.icon, this.label, this.value, {this.widget});
  final IconData icon;
  final String label;
  final String value;

  /// Replaces the value text (the priority chip, for instance).
  final Widget? widget;

  bool get isEmpty => widget == null && (value.isEmpty || value == '—');
}

/// The «اطلاعات اصلی» card of a template detail, with an icon per row. It is
/// the template-specific content the shared [RequestDetailScaffold] gets
/// through its `infoBuilder` slot; rows without a value are skipped.
class TemplateInfoCard extends StatelessWidget {
  const TemplateInfoCard({required this.title, required this.rows, super.key});
  final String title;
  final List<InfoRowData> rows;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const AsoudIconBox(
                  icon: Icons.attach_file_rounded,
                  color: AsoudColors.primary,
                  size: 28),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 4),
            for (final row in rows.where((row) => !row.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 104,
                          child: Text(row.label,
                              style: const TextStyle(
                                  fontSize: 11, color: AsoudColors.muted))),
                      Expanded(
                          child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: row.widget ??
                                  Text(row.value,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.6,
                                          fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 10),
                      Icon(row.icon, size: 18, color: AsoudColors.muted),
                    ]),
              ),
          ]),
        ),
      );
}

/// Chip for a request priority: «عادی», «مهم» (amber), «فوری» (red).
class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'Urgent' => AsoudColors.danger,
      'High' => AsoudColors.warning,
      _ => AsoudColors.primary,
    };
    return Container(
      key: const ValueKey('priority-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(requestPriorityLabel(priority),
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// Persian labels of the stored links of a request (department, cost center,
/// delivery location, ...). The server's `get_request` carries the codes; a
/// `summary` map with `<key>_label` entries (the list rows and the preview
/// have it) wins, else the label comes from `request_field_options`, else the
/// code is shown.
Future<Map<String, String>> resolveLinkLabels(
  GenericRequestRepository repository,
  RequestDetailView view,
  Map<String, String> fieldTypes,
) async {
  final summary = view.detail.raw['summary'];
  final labels = <String, String>{};
  await Future.wait([
    for (final entry in fieldTypes.entries)
      () async {
        final value = view.detail.values[entry.key];
        if (value is! String || value.isEmpty) return;
        final known =
            summary is Map ? '${summary['${entry.key}_label'] ?? ''}' : '';
        if (known.isNotEmpty) {
          labels[entry.key] = known;
          return;
        }
        final name = value.contains(':') && entry.value == 'Delivery Location'
            ? value.substring(value.indexOf(':') + 1)
            : value;
        try {
          final rows = await repository.fieldOptions(entry.value, txt: name);
          final row =
              rows.where((row) => '${row['value']}' == value).firstOrNull;
          labels[entry.key] = row == null ? name : '${row['label'] ?? name}';
        } catch (_) {
          labels[entry.key] = name;
        }
      }(),
  ]);
  return labels;
}

/// Builds a [TemplateInfoCard] once the link labels are known (the codes are
/// shown meanwhile).
class ResolvedInfoCard extends StatefulWidget {
  const ResolvedInfoCard({
    required this.repository,
    required this.view,
    required this.title,
    required this.fieldTypes,
    required this.rows,
    super.key,
  });

  final GenericRequestRepository repository;
  final RequestDetailView view;
  final String title;

  /// Value key to `request_field_options` field type.
  final Map<String, String> fieldTypes;

  /// Rows from the resolved labels (key to label).
  final List<InfoRowData> Function(Map<String, String> labels) rows;

  @override
  State<ResolvedInfoCard> createState() => _ResolvedInfoCardState();
}

class _ResolvedInfoCardState extends State<ResolvedInfoCard> {
  late final Future<Map<String, String>> labels =
      resolveLinkLabels(widget.repository, widget.view, widget.fieldTypes);

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, String>>(
        future: labels,
        builder: (context, snapshot) => TemplateInfoCard(
            title: widget.title, rows: widget.rows(snapshot.data ?? const {})),
      );
}
