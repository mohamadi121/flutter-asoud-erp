import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/presentation/widgets/request_link_fields.dart';
import '../../domain/request_type_catalog.dart';
import '../cubit/request_type_builder_cubit.dart';

/// Step 3: try the request form without saving preview values.
class RequestFormPreviewStep extends StatefulWidget {
  const RequestFormPreviewStep({super.key});

  @override
  State<RequestFormPreviewStep> createState() => _RequestFormPreviewStepState();
}

class _RequestFormPreviewStepState extends State<RequestFormPreviewStep> {
  final formKey = GlobalKey<FormState>();
  late final today = formatJalaliIso(DateTime.now().toIso8601String());

  void _validate() {
    if (formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فرم معتبر است.')));
    }
  }

  String _baseValue(String label) => switch (label) {
        'شماره درخواست' => 'خودکار',
        'ثبت‌کننده درخواست' => 'کاربر جاری',
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
                  const Text('پیش‌نمایش فرم درخواست',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'فرم ثبت درخواست برای کاربران به این شکل نمایش داده می‌شود. این پیش‌نمایش ذخیره نمی‌شود.',
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
                          const Text('اطلاعات پایه',
                              style: AsoudFormStyle.sectionTitle),
                          const SizedBox(height: 12),
                          for (final label in requestBaseFields)
                            Padding(
                              padding: AsoudFormStyle.fieldPadding,
                              child: TextFormField(
                                initialValue: _baseValue(label),
                                enabled: false,
                                maxLines: label == 'شرح درخواست' ? 3 : 1,
                                decoration: InputDecoration(labelText: label),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text('اطلاعات اختصاصی',
                              style: AsoudFormStyle.sectionTitle),
                          const SizedBox(height: 12),
                          if (state.fields.isEmpty)
                            const Text(
                                'فیلد اختصاصی تعریف نشده است؛ فقط فیلدهای پایه نمایش داده می‌شوند.',
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.6,
                                    color: AsoudColors.muted)),
                          for (final field in state.fields)
                            _PreviewField(key: ValueKey(field), field: field),
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
  late final controller =
      TextEditingController(text: widget.field.defaultValue);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _emptyOptions(String query) async => [];

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
        return FormField<bool>(
          initialValue:
              field.defaultValue == 'true' || field.defaultValue == '1',
          validator: (value) =>
              field.required && value != true ? 'این فیلد الزامی است.' : null,
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
                border: InputBorder.none, errorText: state.errorText),
            child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label, style: const TextStyle(fontSize: 12)),
                value: state.value ?? false,
                onChanged: state.didChange),
          ),
        );
      case 'Attachment':
        return FormField<String>(
          validator: _required,
          builder: (state) => InputDecorator(
            decoration:
                InputDecoration(labelText: label, errorText: state.errorText),
            child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('انتخاب فایل')),
          ),
        );
      case 'User':
      case 'Department':
        return RequestLinkField(
            label: label,
            required: field.required,
            loader: _emptyOptions,
            onChanged: (_) {});
      case 'Item Table':
        return RequestItemTableField(
            label: label,
            required: field.required,
            items: _emptyOptions,
            uoms: _emptyOptions,
            onChanged: (_) {});
      default:
        final numeric = field.type == 'Number' || field.type == 'Currency';
        return TextFormField(
          controller: controller,
          maxLines: field.type == 'Long Text' ? 3 : 1,
          keyboardType: numeric ? TextInputType.number : null,
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
