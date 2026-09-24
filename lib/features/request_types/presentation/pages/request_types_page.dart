import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';
import '../../domain/request_type_catalog.dart';
import '../cubit/request_type_builder_cubit.dart';
import 'request_type_builder_page.dart';

/// Admin list of request types, the entry point of the builder.
class RequestTypesPage extends StatefulWidget {
  const RequestTypesPage({required this.company, super.key});
  final String company;

  @override
  State<RequestTypesPage> createState() => _RequestTypesPageState();
}

class _RequestTypesPageState extends State<RequestTypesPage> {
  late Future<List<WorkflowDefinition>> future = _load();
  String query = '';

  Future<List<WorkflowDefinition>> _load() async => (await context
          .read<WorkflowRepository>()
          .getWorkflows(company: widget.company))
      .where((item) => item.targetDoctype == requestTargetDoctype)
      .toList();

  void _reload() => setState(() {
        future = _load();
      });

  Future<void> _open([WorkflowDefinition? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RequestTypeBuilderPage(
            company: widget.company, existing: existing)));
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'انواع درخواست',
              subtitle: 'تعریف فرم، گردش کار و دسترسی هر درخواست'),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'جستجو در انواع درخواست‌ها...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WorkflowDefinition>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton(
                            onPressed: _reload,
                            child: const Text('دریافت ناموفق؛ تلاش دوباره')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!
                      .where((item) =>
                          query.isEmpty ||
                          item.title.contains(query) ||
                          (item.shortTitle ?? '').contains(query))
                      .toList();
                  if (items.isEmpty) {
                    return const Center(
                        child: Text('هنوز نوع درخواستی تعریف نشده است.',
                            style: TextStyle(color: AsoudColors.muted)));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        for (final item in items)
                          _RequestTypeCard(
                              item: item, onTap: () => _open(item)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
          bottomNavigationBar: AsoudBottomActions(
              primaryLabel: 'ایجاد نوع درخواست جدید', onPrimary: _open),
        ),
      );
    }

    class _RequestTypeCard extends StatelessWidget {
      const _RequestTypeCard({required this.item, required this.onTap});
      final WorkflowDefinition item;
      final VoidCallback onTap;

      @override
      Widget build(BuildContext context) {
        final visual = requestIconFor(item.iconKey);
        final subtitle = item.shortTitle?.isNotEmpty == true
            ? item.shortTitle!
            : item.description?.isNotEmpty == true
                ? item.description!
                : item.code;
        final (badge, badgeColor) = item.status == WorkflowDefinitionStatus.active
            ? (null, AsoudColors.success)
            : item.isLocked
                ? ('نیازمند تکمیل', AsoudColors.warning)
                : ('غیرفعال', AsoudColors.muted);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                AsoudIconBox(icon: visual.icon, color: visual.color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 9,
                            color: badgeColor,
                            fontWeight: FontWeight.w800)),
                  ),
                const Icon(Icons.chevron_left_rounded, color: AsoudColors.muted),
              ]),
            ),
          ),
        );
      }
    }
