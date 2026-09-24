import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../domain/request_type_catalog.dart';
import '../cubit/request_type_builder_cubit.dart';

/// Step 1: name, description, category, icon, status and visibility.
class RequestInfoStep extends StatefulWidget {
  const RequestInfoStep({required this.formKey, super.key});
  final GlobalKey<FormState> formKey;

  @override
  State<RequestInfoStep> createState() => _RequestInfoStepState();
}

class _RequestInfoStepState extends State<RequestInfoStep> {
  late final RequestTypeBuilderCubit cubit =
      context.read<RequestTypeBuilderCubit>();
  late final RequestTypeInfo initial = cubit.state.info;
  late final title = TextEditingController(text: initial.title);
  late final shortTitle = TextEditingController(text: initial.shortTitle);
  late final description = TextEditingController(text: initial.description);
  late String category = initial.category;
  late String iconKey = initial.iconKey;
  late bool showInList = initial.showInList;
  late bool userSubmittable = initial.userSubmittable;

  @override
  void dispose() {
    title.dispose();
    shortTitle.dispose();
    description.dispose();
    super.dispose();
  }

  void _changed() => cubit.updateInfo(RequestTypeInfo(
        title: title.text.trim(),
        shortTitle: shortTitle.text.trim(),
        description: description.text.trim(),
        category: category,
        iconKey: iconKey,
        colorHex: requestIconFor(iconKey).hex,
        showInList: showInList,
        userSubmittable: userSubmittable,
      ));

  @override
  Widget build(BuildContext context) => Form(
        key: widget.formKey,
        onChanged: _changed,
        child: ListView(padding: AsoudFormStyle.pagePadding, children: [
          const Text('اطلاعات کلی',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          AsoudFormField(
              controller: title,
              label: 'نام درخواست *',
              hint: 'مثال: درخواست خرید',
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'نام درخواست حداقل ۳ حرف باشد.'
                  : null),
          AsoudFormField(
              controller: shortTitle,
              label: 'عنوان کوتاه',
              hint: 'مثال: خرید کالا و خدمات'),
          AsoudFormField(
              controller: description,
              label: 'توضیحات درخواست',
              lines: 3,
              hint: 'کاربرد این درخواست برای کاربران'),
          Padding(
            padding: AsoudFormStyle.fieldPadding,
            child: DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'دسته‌بندی'),
              items: [
                for (final item in requestCategories)
                  DropdownMenuItem(value: item.key, child: Text(item.label)),
              ],
              onChanged: (value) {
                category = value ?? category;
                _changed();
              },
            ),
          ),
          const SizedBox(height: 6),
          const Text('آیکون',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              for (final option in requestIcons)
                _IconChoice(
                  option: option,
                  selected: option.key == iconKey,
                  onTap: () {
                    setState(() => iconKey = option.key);
                    _changed();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          BlocSelector<RequestTypeBuilderCubit, RequestTypeBuilderState, bool>(
            selector: (state) => state.active,
            builder: (context, active) => _Toggle(
                label: 'فعال',
                subtitle: 'پس از تکمیل گردش کار قابل ثبت است',
                value: active,
                onChanged: cubit.setActive),
          ),
          _Toggle(
              label: 'نمایش در لیست درخواست‌ها',
              value: showInList,
              onChanged: (value) {
                setState(() => showInList = value);
                _changed();
              }),
          _Toggle(
              label: 'امکان ثبت توسط کاربران',
              value: userSubmittable,
              onChanged: (value) {
                setState(() => userSubmittable = value);
                _changed();
              }),
        ]),
      );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice(
      {required this.option, required this.selected, required this.onTap});
  final RequestIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: option.color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AsoudColors.primary : Colors.transparent,
                width: 2),
          ),
          child: Icon(option.icon, color: option.color, size: 24),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.subtitle});
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
        value: value,
        onChanged: onChanged,
      );
}
