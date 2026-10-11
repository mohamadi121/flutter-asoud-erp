import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/app_fields.dart';
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
          AppTextField(
              controller: title,
              label: 'نام درخواست',
              required: true,
              hint: 'مثال: درخواست خرید',
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'نام درخواست حداقل ۳ حرف باشد.'
                  : null),
          const SizedBox(height: 12),
          AppTextField(
              controller: shortTitle,
              label: 'عنوان کوتاه',
              hint: 'مثال: خرید کالا و خدمات'),
          const SizedBox(height: 12),
          AppTextField(
              controller: description,
              label: 'توضیحات درخواست',
              maxLines: 3,
              hint: 'کاربرد این درخواست برای کاربران'),
          const SizedBox(height: 12),
          AppSelectField(
              label: 'دسته‌بندی',
              value: category,
              displayValue: requestCategories
                  .where((item) => item.key == category)
                  .map((item) => item.label)
                  .firstOrNull,
              hint: 'انتخاب دسته',
              onPick: () => showAppOptionSheet(context,
                  title: 'دسته‌بندی',
                  current: category,
                  options: [
                    for (final item in requestCategories)
                      AppOption(item.key, item.label)
                  ]),
              onChanged: (value) {
                category = value;
                _changed();
              }),
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
            builder: (context, active) => AppSwitchTile(
                title: 'فعال',
                subtitle: 'پس از تکمیل گردش کار قابل ثبت است',
                value: active,
                onChanged: cubit.setActive),
          ),
          const SizedBox(height: 8),
          AppSwitchTile(
              title: 'نمایش در لیست درخواست‌ها',
              value: showInList,
              onChanged: (value) {
                setState(() => showInList = value);
                _changed();
              }),
          const SizedBox(height: 8),
          AppSwitchTile(
              title: 'امکان ثبت توسط کاربران',
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
