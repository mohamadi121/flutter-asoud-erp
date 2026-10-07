import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/workflow_definition.dart';

/// An empty selection means the whole unit, not a snapshot of its current staff.
class StagePeopleSheet extends StatefulWidget {
  const StagePeopleSheet({
    required this.employees,
    required this.selected,
    required this.allSelected,
    required this.unitLabel,
    this.allowAll = true,
    super.key,
  });

  final List<WorkflowTargetOption> employees;
  final Set<String> selected;
  final bool allSelected;
  final bool allowAll;
  final String unitLabel;

  @override
  State<StagePeopleSheet> createState() => _StagePeopleSheetState();
}

class _StagePeopleSheetState extends State<StagePeopleSheet> {
  late final selected = {...widget.selected};
  late bool all = widget.allSelected;
  String search = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.employees.where(
        (item) => '${item.label} ${item.designation ?? ''}'.contains(search));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(children: [
              Row(children: [
                const Expanded(
                    child: Text('انتخاب افراد',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'بستن',
                    icon: const Icon(Icons.close_rounded)),
              ]),
              TextField(
                onChanged: (value) => setState(() => search = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'جستجو در افراد واحد سازمانی...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.allowAll)
                CheckboxListTile(
                  value: all,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('همه افراد ${widget.unitLabel}'),
                  secondary: const Icon(Icons.groups_outlined,
                      color: AsoudColors.primary),
                  onChanged: (value) => setState(() {
                    all = value ?? false;
                    if (all) {
                      selected.clear();
                    }
                  }),
                ),
              Expanded(
                  child: ListView(children: [
                if (visible.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('فردی برای نمایش یافت نشد.')),
                for (final item in visible)
                  CheckboxListTile(
                    value: !all && selected.contains(item.id),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.label),
                    subtitle: item.designation == null
                        ? null
                        : Text(item.designation!),
                    secondary: const Icon(Icons.person_outline_rounded,
                        color: AsoudColors.primary),
                    onChanged: (checked) => setState(() {
                      all = false;
                      if (checked == true) {
                        selected.add(item.id);
                      } else {
                        selected.remove(item.id);
                      }
                    }),
                  ),
              ])),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: all || selected.isNotEmpty
                        ? () =>
                            Navigator.pop(context, all ? <String>{} : selected)
                        : null,
                    child: const Text('تأیید انتخاب'),
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
