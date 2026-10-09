import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../domain/request_type_catalog.dart';
import '../cubit/request_type_builder_cubit.dart';
import '../pages/request_field_editor_page.dart';

class RequestFormStep extends StatelessWidget {
  const RequestFormStep({super.key});

  Future<void> _edit(BuildContext context,
      List<WorkflowFormFieldDefinition> fields, int? index) async {
    final cubit = context.read<RequestTypeBuilderCubit>();
    final result =
        await Navigator.of(context).push<WorkflowFormFieldDefinition>(
      MaterialPageRoute(
          builder: (_) => RequestFieldEditorPage(
                type: index == null ? 'Short Text' : fields[index].type,
                initial: index == null ? null : fields[index],
                takenKeys: {
                  for (var i = 0; i < fields.length; i++)
                    if (i != index) fields[i].key,
                },
              )),
    );
    if (result == null || !context.mounted || cubit.isClosed) return;
    final updated = [...fields];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    cubit.setFields(updated);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RequestTypeBuilderCubit, RequestTypeBuilderState>(
        builder: (context, state) {
          final fields = state.fields;
          final VoidCallback? add = fields.length >= 30 || state.saving
              ? null
              : () => _edit(context, fields, null);
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            buildDefaultDragHandles: false,
            header: Column(children: [
              _AddFieldButton(onPressed: add),
              const SizedBox(height: 12),
              _BaseFieldsHeader(state: state),
            ]),
            footer: fields.isEmpty
                ? const _EmptyFields()
                : const SizedBox(height: 8),
            itemCount: fields.length,
            onReorderItem: (from, to) {
              if (state.saving) return;
              final updated = [...fields];
              updated.insert(to, updated.removeAt(from));
              context
                  .read<RequestTypeBuilderCubit>()
                  .setFields(updated, reorderLayout: true);
            },
            itemBuilder: (context, index) => _FieldRow(
              key: ValueKey(fields[index].key),
              field: fields[index],
              index: index,
              enabled: !state.saving,
              onTap: () => _edit(context, fields, index),
              onDelete: () => context
                  .read<RequestTypeBuilderCubit>()
                  .setFields([...fields]..removeAt(index)),
            ),
          );
        },
      );
}

class _BaseFieldsHeader extends StatelessWidget {
  const _BaseFieldsHeader({required this.state});
  final RequestTypeBuilderState state;
  static const base = [
    ('شماره درخواست', 'خودکار', Icons.tag_rounded),
    ('ثبت‌کننده درخواست', 'کاربر جاری', Icons.person_outline_rounded),
    ('واحد سازمانی', 'واحد ثبت‌کننده', Icons.account_tree_outlined),
    ('تاریخ ثبت', 'هنگام ثبت درخواست', Icons.calendar_today_outlined),
    ('وضعیت درخواست', 'براساس گردش کار', Icons.flag_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final icon = requestIconFor(state.info.iconKey);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AsoudColors.primary.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AsoudIconBox(icon: icon.icon, color: icon.color, size: 36),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.info.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  if (state.info.description.isNotEmpty)
                    Text(state.info.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                ])),
            TextButton.icon(
                onPressed: state.saving
                    ? null
                    : context.read<RequestTypeBuilderCubit>().back,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('ویرایش', style: TextStyle(fontSize: 11))),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final field in base)
                        SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _BaseTile(
                                label: field.$1,
                                value: field.$2,
                                icon: field.$3)),
                    ],
                  )),
          const SizedBox(height: 8),
          const _BaseTile(
              label: 'شرح درخواست',
              value: 'توسط ثبت‌کننده تکمیل می‌شود',
              icon: Icons.description_outlined),
          const SizedBox(height: 8),
          const _BaseTile(
              label: 'فایل پیوست',
              value: 'فایل‌های مرتبط با درخواست',
              icon: Icons.attach_file_rounded),
        ]),
      ),
      const SizedBox(height: 20),
      Text(
          state.fields.isEmpty
              ? 'ساخت فرم درخواست'
              : 'فیلدهای اختصاصی فرم درخواست',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('فیلدهای اختصاصی این نوع درخواست را اضافه کنید.',
          style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
      const SizedBox(height: 12),
    ]);
  }
}

class _BaseTile extends StatelessWidget {
  const _BaseTile(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AsoudColors.surface,
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 20, color: AsoudColors.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AsoudColors.muted)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600)),
              ])),
        ]),
      );
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AsoudColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AsoudColors.border)),
        child: Column(children: [
          const AsoudIconBox(
              icon: Icons.add_rounded, color: AsoudColors.primary, size: 44),
          const SizedBox(height: 12),
          const Text('هنوز فیلد اختصاصی ندارید',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('برای ساخت فرم، فیلدهای مورد نیاز را اضافه کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
          const SizedBox(height: 16),
          const Text('از دکمهٔ بالای صفحه استفاده کنید.',
              style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        ]),
      );
}

class _AddFieldButton extends StatelessWidget {
  const _AddFieldButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(
                backgroundColor: AsoudColors.primary.withValues(alpha: .06),
                minimumSize: const Size.fromHeight(44)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('افزودن فیلد جدید')),
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow(
      {required this.field,
      required this.index,
      required this.onTap,
      required this.onDelete,
      required this.enabled,
      super.key});
  final WorkflowFormFieldDefinition field;
  final int index;
  final bool enabled;
  final VoidCallback onTap, onDelete;
  @override
  Widget build(BuildContext context) {
    final type = requestFieldTypeFor(
        field.label.trim() == 'تاریخ ثبت' ? 'Date' : field.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: field.type == 'Table' || field.type == 'Item Table'
              ? AsoudColors.primary.withValues(alpha: .06)
              : AsoudColors.surface,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(type.icon, size: 20, color: AsoudColors.primary)),
        Expanded(
            child: InkWell(
                onTap: enabled ? onTap : null,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(field.label,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(
                              '${type.label}${field.required ? ' • الزامی' : ''}',
                              style: const TextStyle(
                                  fontSize: 10, color: AsoudColors.muted)),
                        ])))),
        IconButton(
            tooltip: 'ویرایش فیلد',
            onPressed: enabled ? onTap : null,
            icon: const Icon(Icons.edit_outlined,
                color: AsoudColors.primary, size: 19)),
        IconButton(
            tooltip: 'حذف فیلد',
            onPressed: enabled ? onDelete : null,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AsoudColors.danger, size: 20)),
        ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 20, color: AsoudColors.muted))),
      ]),
    );
  }
}
