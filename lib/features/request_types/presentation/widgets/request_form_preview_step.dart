import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../workflows/data/generic_request_repository.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/presentation/widgets/request_link_fields.dart';
import '../../../workflows/presentation/widgets/request_custom_table.dart';
import '../../domain/request_type_catalog.dart';
import '../../domain/request_form_layout.dart';
import '../cubit/request_type_builder_cubit.dart';
import '../pages/request_field_editor_page.dart';

/// Step 3: try the request form without saving preview values.
class RequestFormPreviewStep extends StatefulWidget {
  const RequestFormPreviewStep({super.key});

  @override
  State<RequestFormPreviewStep> createState() => _RequestFormPreviewStepState();
}

class _RequestFormPreviewStepState extends State<RequestFormPreviewStep> {
  final formKey = GlobalKey<FormState>();
  late final today = formatJalaliIso(DateTime.now().toIso8601String());

  Future<void> _edit([WorkflowFormFieldDefinition? field]) async {
    final cubit = context.read<RequestTypeBuilderCubit>();
    if (cubit.state.saving) return;
    final result = await Navigator.push<WorkflowFormFieldDefinition>(
        context,
        MaterialPageRoute(
            builder: (_) => RequestFieldEditorPage(
                  type: field?.type ?? 'Short Text',
                  initial: field,
                  takenKeys: {
                    for (final item in cubit.state.fields)
                      if (item.key != field?.key) item.key
                  },
                )));
    if (result == null || !mounted || cubit.isClosed) return;
    cubit.setFields([
      for (final item in cubit.state.fields)
        item.key == field?.key ? result : item,
      if (field == null) result,
    ]);
  }

  void _validate() {
    if (formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فرم معتبر است.')));
    }
  }

  String _baseValue(String label) => switch (label) {
        'شماره درخواست' => 'خودکار',
        'ثبت‌کننده درخواست' => 'کاربر جاری',
        'واحد سازمانی' => 'واحد ثبت‌کننده',
        'فایل پیوست' => 'پیوست‌های ثبت‌کننده',
        'تاریخ ثبت' => today,
        'وضعیت درخواست' => 'در انتظار',
        _ => '',
      };

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RequestTypeBuilderCubit, RequestTypeBuilderState>(
        builder: (context, state) {
          final icon = requestIconFor(state.info.iconKey);
          return SingleChildScrollView(
            padding: AsoudFormStyle.pagePadding,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                      onPressed: state.saving || state.fields.length >= 30
                          ? null
                          : () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن فیلد جدید')),
                  const Text('پیش‌نمایش فرم درخواست',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'با کشیدن دستگیره، فیلدها را بالا، پایین، چپ و راست جابه‌جا کنید. اندازه و ترتیب ذخیره می‌شود؛ مقادیر آزمایشی ذخیره نمی‌شوند.',
                      style: TextStyle(
                          fontSize: 11, height: 1.6, color: AsoudColors.muted)),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            AsoudIconBox(
                                icon: icon.icon, color: icon.color, size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(state.info.title,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900)),
                                  if (state.info.shortTitle.isNotEmpty)
                                    Text(state.info.shortTitle,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AsoudColors.muted)),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          LayoutBuilder(builder: (context, constraints) {
                            final cubit =
                                context.read<RequestTypeBuilderCubit>();
                            return Wrap(spacing: 10, runSpacing: 10, children: [
                              for (final item in cubit.layout)
                                SizedBox(
                                  key: ValueKey(item.key),
                                  width: item.fullWidth
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 10) / 2,
                                  child: DragTarget<String>(
                                    onWillAcceptWithDetails: (drag) =>
                                        !state.saving && drag.data != item.key,
                                    onAcceptWithDetails: (drag) =>
                                        cubit.moveField(drag.data, item.key),
                                    builder: (context, candidates, rejected) =>
                                        Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: candidates.isEmpty
                                              ? AsoudColors.surface
                                              : AsoudColors.primary
                                                  .withValues(alpha: .1),
                                          border: Border.all(
                                              color: AsoudColors.border),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(children: [
                                              LongPressDraggable<String>(
                                                  data: item.key,
                                                  maxSimultaneousDrags:
                                                      state.saving ? 0 : 1,
                                                  feedback: Material(
                                                      elevation: 4,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  16),
                                                          child: Text(requestBaseLayout[item.key] ??
                                                              state.fields
                                                                  .firstWhere((f) =>
                                                                      f.key ==
                                                                      item.key)
                                                                  .label))),
                                                  child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Icon(Icons.drag_indicator, size: 20, color: AsoudColors.muted))),
                                              const Spacer(),
                                              if (!requestBaseLayout
                                                  .containsKey(item.key))
                                                IconButton(
                                                    tooltip: 'ویرایش فیلد',
                                                    constraints:
                                                        const BoxConstraints
                                                            .tightFor(
                                                            width: 28,
                                                            height: 32),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: state.saving
                                                        ? null
                                                        : () => _edit(state
                                                            .fields
                                                            .firstWhere(
                                                                (field) =>
                                                                    field.key ==
                                                                    item.key)),
                                                    icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 16)),
                                              IconButton(
                                                  constraints:
                                                      const BoxConstraints
                                                          .tightFor(
                                                          width: 28,
                                                          height: 32),
                                                  padding: EdgeInsets.zero,
                                                  tooltip: item.fullWidth
                                                      ? 'نیم‌عرض'
                                                      : 'تمام‌عرض',
                                                  onPressed: state.saving
                                                      ? null
                                                      : () => cubit.resizeField(
                                                          item.key),
                                                  icon: Icon(
                                                      item.fullWidth
                                                          ? Icons
                                                              .view_column_outlined
                                                          : Icons
                                                              .width_full_outlined,
                                                      size: 18)),
                                            ]),
                                            if (requestBaseLayout.containsKey(item.key))
                                              TextFormField(
                                                  key: ValueKey(
                                                      '${item.key}:${state.info.description}'),
                                                  initialValue: item.key ==
                                                          'base:description'
                                                      ? state.info.description
                                                      : _baseValue(
                                                          requestBaseLayout[
                                                              item.key]!),
                                                  enabled: false,
                                                  maxLines:
                                                      item.key == 'base:description'
                                                          ? 3
                                                          : 2,
                                                  decoration: InputDecoration(
                                                      labelText: requestBaseLayout[
                                                          item.key]))
                                            else
                                              _PreviewField(
                                                  key: ValueKey(state.fields
                                                      .firstWhere((field) =>
                                                          field.key == item.key)),
                                                  field: state.fields.firstWhere((field) => field.key == item.key)),
                                          ]),
                                    ),
                                  ),
                                ),
                            ]);
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _validate,
                      child: const Text('آزمایش اعتبارسنجی')),
                ],
              ),
            ),
          );
        },
      );
}

class _PreviewField extends StatefulWidget {
  const _PreviewField({required this.field, super.key});
  final WorkflowFormFieldDefinition field;

  @override
  State<_PreviewField> createState() => _PreviewFieldState();
}

class _PreviewFieldState extends State<_PreviewField> {
  GenericRequestRepository? _repository;
  late final controller =
      TextEditingController(text: widget.field.defaultValue);

  @override
  void dispose() {
    _repository?.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _options(String type, String query,
      {String? itemCode}) {
    final company = context.read<RequestTypeBuilderCubit>().company;
    if (company == null || company.isEmpty) {
      throw StateError('برای انتخاب اطلاعات مرجع، ابتدا دفتر را انتخاب کنید.');
    }
    _repository ??=
        GenericRequestRepository(context.read<FrappeApiClient>(), company);
    return _repository!.fieldOptions(type, txt: query, itemCode: itemCode);
  }

  Future<String?> _pickPreviewFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'docx']);
    if (!mounted || result == null) return null;
    if (result.files.single.size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حداکثر حجم فایل ۱۰ مگابایت است.')));
      return null;
    }
    // Preview only: no file content is uploaded or persisted with the definition.
    return result.files.single.name;
  }

  String? _required(String? value) =>
      widget.field.required && (value == null || value.trim().isEmpty)
          ? 'این فیلد الزامی است.'
          : null;

  Widget _input() {
    final field = widget.field;
    final label = '${field.label}${field.required ? ' *' : ''}';
    switch (field.type) {
      case 'Date':
        return AsoudFormDateField(
            controller: controller, label: label, required: field.required);
      case 'Choice':
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(field.defaultValue)
              ? field.defaultValue
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          validator: _required,
          items: [
            for (final option in field.options)
              DropdownMenuItem(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (_) {},
        );
      case 'Multi Choice':
        return RequestMultiChoiceField(
            label: label,
            options: field.options,
            required: field.required,
            initialValue: [
              if (field.options.contains(field.defaultValue))
                field.defaultValue,
            ],
            onChanged: (_) {});
      case 'Checkbox':
        return RequestBooleanField(
            label: label,
            required: field.required,
            initialValue: field.defaultValue.isEmpty
                ? null
                : field.defaultValue == 'true' || field.defaultValue == '1',
            onChanged: (_) {});
      case 'Attachment':
        return FormField<String>(
          validator: _required,
          builder: (state) => InputDecorator(
            decoration:
                InputDecoration(labelText: label, errorText: state.errorText),
            child: OutlinedButton.icon(
                onPressed: () async {
                  final name = await _pickPreviewFile();
                  if (name != null && state.mounted) state.didChange(name);
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(state.value ?? 'انتخاب فایل',
                    overflow: TextOverflow.ellipsis)),
          ),
        );
      case 'User':
      case 'Department':
        return RequestLinkField(
            label: label,
            required: field.required,
            loader: (query) => _options(field.type, query),
            onChanged: (_) {});
      case 'Item Table':
        return RequestItemTableField(
            label: label,
            required: field.required,
            items: (query) => _options('Item', query),
            uoms: (code) => _options('UOM', '', itemCode: code),
            onChanged: (_) {});
      case 'Table':
        return RequestCustomTable(
            field: field,
            uploadAttachment: _pickPreviewFile,
            onChanged: (_) {});
      default:
        final numeric = field.type == 'Number' || field.type == 'Currency';
        return TextFormField(
          controller: controller,
          maxLines: field.type == 'Long Text' ? 3 : 1,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true)
              : null,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final missing = _required(value);
            if (missing != null) return missing;
            if (numeric && (value ?? '').isNotEmpty) {
              final number = num.tryParse(value!);
              if (number == null || !number.isFinite) {
                return 'عدد معتبر وارد کنید.';
              }
            }
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _input(),
            if (widget.field.helpText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.field.helpText,
                    style: const TextStyle(
                        fontSize: 11, height: 1.5, color: AsoudColors.muted)),
              ),
          ],
        ),
      );
}
