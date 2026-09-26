import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../domain/request_type_catalog.dart';
import '../cubit/request_type_builder_cubit.dart';
import '../pages/request_field_editor_page.dart';
import 'field_type_sheet.dart';

/// Step 2: the base fields are fixed; custom fields are added, edited,
/// reordered and removed here (at most 30).
class RequestFormStep extends StatelessWidget {
  const RequestFormStep({super.key});

  Future<void> _edit(BuildContext context,
      List<WorkflowFormFieldDefinition> fields, int? index) async {
    final cubit = context.read<RequestTypeBuilderCubit>();
    final String type;
    if (index == null) {
      final picked = await showFieldTypeSheet(context);
      if (picked == null || !context.mounted) return;
      type = picked.type;
    } else {
      type = fields[index].type;
    }
    final result =
        await Navigator.of(context).push<WorkflowFormFieldDefinition>(
      MaterialPageRoute(
        builder: (_) => RequestFieldEditorPage(
          type: type,
          initial: index == null ? null : fields[index],
          takenKeys: {
            for (var i = 0; i < fields.length; i++)
              if (i != index) fields[i].key,
          },
        ),
      ),
    );
    if (result == null) return;
    final updated = [...fields];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    cubit.setFields(updated);
  }

  @override
  Widget build(BuildContext context) => BlocSelector<RequestTypeBuilderCubit,
          RequestTypeBuilderState, List<WorkflowFormFieldDefinition>>(
        selector: (state) => state.fields,
        builder: (context, fields) => ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          buildDefaultDragHandles: false,
          header: const _BaseFieldsHeader(),
          footer: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: fields.length >= 30
                  ? null
                  : () => _edit(context, fields, null),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('افزودن فیلد جدید'),
            ),
          ),
          itemCount: fields.length,
          onReorderItem: (from, to) {
            final updated = [...fields];
            updated.insert(to, updated.removeAt(from));
            context.read<RequestTypeBuilderCubit>().setFields(updated);
          },
          itemBuilder: (context, index) => _FieldRow(
            key: ValueKey(fields[index].key),
            field: fields[index],
            index: index,
            onTap: () => _edit(context, fields, index),
            onDelete: () => context
                .read<RequestTypeBuilderCubit>()
                .setFields([...fields]..removeAt(index)),
          ),
        ),
      );
}

class _BaseFieldsHeader extends StatelessWidget {
  const _BaseFieldsHeader();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ساخت فرم درخواست',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AsoudColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AsoudColors.primary.withValues(alpha: .25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: AsoudColors.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'فیلدهای پایه به‌صورت پیش‌فرض در همه درخواست‌ها وجود دارند:',
                        style: TextStyle(fontSize: 11, height: 1.5)),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final label in requestBaseFields)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AsoudColors.surface,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('فیلدهای اختصاصی',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
        ],
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.index,
    required this.onTap,
    required this.onDelete,
    super.key,
  });
  final WorkflowFormFieldDefinition field;
  final int index;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final type = requestFieldTypeFor(field.type);
    final badgeColor = field.required ? AsoudColors.primary : AsoudColors.muted;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            IconButton(
              tooltip: 'حذف فیلد',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AsoudColors.danger, size: 20),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: AsoudColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(type.icon, size: 18, color: AsoudColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(type.label,
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(field.required ? 'اجباری' : 'اختیاری',
                  style: TextStyle(
                      fontSize: 9,
                      color: badgeColor,
                      fontWeight: FontWeight.w800)),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator_rounded,
                    color: AsoudColors.muted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
