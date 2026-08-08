import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../cubit/workflow_form_cubit.dart';
import 'workflow_designer_page.dart';

class WorkflowFormPage extends StatelessWidget {
  const WorkflowFormPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkflowFormCubit(
          repository: context.read<WorkflowRepository>(),
        )..load(),
        child: const _WorkflowFormView(),
      );
}

class _WorkflowFormView extends StatelessWidget {
  const _WorkflowFormView();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WorkflowFormCubit, WorkflowFormState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.message != current.message,
        listener: (context, state) {
          if (state.status == WorkflowFormStatus.success &&
              state.createdDraft != null) {
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) =>
                  WorkflowDesignerPage(definition: state.createdDraft!.id),
            ));
          } else if (state.status == WorkflowFormStatus.failure &&
              state.options != null &&
              state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) => Scaffold(
          appBar: const AsoudHeader(
            title: 'ایجاد گردش‌کار',
            subtitle: 'اطلاعات پایه فرایند را وارد کنید',
          ),
          body: switch (state.status) {
            WorkflowFormStatus.initial ||
            WorkflowFormStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            WorkflowFormStatus.failure when state.options == null =>
              _LoadFailure(message: state.message ?? 'خطا در دریافت اطلاعات'),
            _ => _FormContent(state: state),
          },
          bottomNavigationBar: state.options == null
              ? null
              : AsoudBottomActions(
                  primaryLabel: state.status == WorkflowFormStatus.submitting
                      ? 'در حال ذخیره...'
                      : 'ذخیره و طراحی مراحل',
                  onPrimary: state.status == WorkflowFormStatus.submitting
                      ? null
                      : context.read<WorkflowFormCubit>().submit,
                  secondaryLabel: 'انصراف',
                  onSecondary: () => Navigator.pop(context),
                ),
        ),
      );
}

class _FormContent extends StatelessWidget {
  const _FormContent({required this.state});
  final WorkflowFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkflowFormCubit>();
    final module = state.options?.modules
        .where((item) => item.key == state.moduleKey)
        .firstOrNull;
    final available =
        module?.doctypes.where((item) => item.available).toList() ?? const [];
    final unavailable =
        module?.doctypes.where((item) => !item.available).toList() ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
      children: [
        if (state.offlinePreview) const AsoudOfflinePreviewBanner(),
        const _InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'ابتدا مشخصات پایه ثبت می‌شود؛ مراحل، تأییدکنندگان و شرط‌ها در صفحه بعد طراحی خواهند شد.',
          color: AsoudColors.primary,
        ),
        const SizedBox(height: 12),
        const _SectionTitle(number: '۱', title: 'روش ایجاد فرایند'),
        AsoudSegmentedControl<String>(
          value: state.creationMode,
          options: const [
            AsoudSegmentedOption(
                value: 'Custom',
                label: 'ایجاد سفارشی',
                icon: Icons.account_tree_outlined),
            AsoudSegmentedOption(
                value: 'Template',
                label: 'قالب پیشنهادی',
                icon: Icons.auto_awesome_outlined),
          ],
          onChanged: cubit.changeCreationMode,
        ),
        const SizedBox(height: 14),
        const _SectionTitle(number: '۲', title: 'اطلاعات اصلی'),
        TextField(
          onChanged: cubit.changeTitle,
          decoration: InputDecoration(
            labelText: 'عنوان فرایند *',
            hintText: 'مثلاً فرایند درخواست خرید کالا',
            prefixIcon: const Icon(Icons.title_rounded),
            errorText: state.titleError,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: cubit.changeDescription,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'توضیح کوتاه',
            hintText: 'هدف و کاربرد این فرایند را بنویسید...',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 50),
              child: Icon(Icons.notes_rounded),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(number: '۳', title: 'دامنه و سند مقصد'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: state.company.isEmpty ? null : state.company,
          decoration: const InputDecoration(
              labelText: 'دفتر / شرکت',
              prefixIcon: Icon(Icons.business_outlined)),
          items: state.options!.companies
              .map((company) => DropdownMenuItem(
                    value: company,
                    child: Text(company, overflow: TextOverflow.ellipsis),
                  ))
              .toList(growable: false),
          onChanged: cubit.changeCompany,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: state.moduleKey.isEmpty ? null : state.moduleKey,
              decoration: const InputDecoration(labelText: 'ماژول *'),
              items: state.options!.modules
                  .map((item) => DropdownMenuItem(
                        value: item.key,
                        child: Text(_moduleLabel(item.key),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(growable: false),
              onChanged: cubit.changeModule,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  state.targetDoctype.isEmpty ? null : state.targetDoctype,
              decoration: const InputDecoration(labelText: 'نوع سند *'),
              items: available
                  .map((item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(_doctypeLabel(item.name),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(growable: false),
              onChanged: cubit.changeDoctype,
            ),
          ),
        ]),
        if (unavailable.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.lock_clock_outlined,
            text:
                '${unavailable.map((item) => _doctypeLabel(item.name)).join('، ')} فعلاً نصب نیست و برای مرحله بعد قفل می‌ماند.',
            color: AsoudColors.warning,
          ),
        ],
        const SizedBox(height: 14),
        const _SectionTitle(number: '۴', title: 'نمای ظاهری'),
        const Text('آیکون فرایند',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            for (final option in const [
              ('hub', Icons.hub_outlined),
              ('purchase', Icons.shopping_cart_outlined),
              ('expense', Icons.account_balance_wallet_outlined),
              ('support', Icons.support_agent_outlined),
              ('leave', Icons.description_outlined),
              ('hiring', Icons.person_add_alt_1_outlined),
            ])
              _IconChoice(
                icon: option.$2,
                selected: state.iconKey == option.$1,
                onTap: () => cubit.changeIcon(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('رنگ فرایند',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          children: [
            for (final option in const [
              ('#315CF5', Color(0xFF315CF5)),
              ('#6C3FF5', Color(0xFF6C3FF5)),
              ('#16A765', Color(0xFF16A765)),
              ('#F59E0B', Color(0xFFF59E0B)),
              ('#EF476F', Color(0xFFEF476F)),
              ('#0E9FB5', Color(0xFF0E9FB5)),
            ])
              _ColorChoice(
                color: option.$2,
                selected: state.colorHex == option.$1,
                onTap: () => cubit.changeColor(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const _InfoBanner(
          icon: Icons.lock_outline_rounded,
          text:
              'فرایند ابتدا به‌صورت پیش‌نویس ذخیره می‌شود و تا تکمیل مراحل و اتصال به Workflow واقعی Frappe فعال نخواهد شد.',
          color: AsoudColors.success,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number, title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AsoudColors.primary.withValues(alpha: .1),
            child: Text(number,
                style: const TextStyle(
                    fontSize: 10,
                    color: AsoudColors.primary,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 7),
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          border: Border.all(color: color.withValues(alpha: .25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(text, style: const TextStyle(fontSize: 9, height: 1.7))),
        ]),
      );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice(
      {required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 47,
          height: 43,
          decoration: BoxDecoration(
            color: selected
                ? AsoudColors.primary.withValues(alpha: .09)
                : Colors.white,
            border: Border.all(
                color: selected ? AsoudColors.primary : AsoudColors.border,
                width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              color: selected ? AsoudColors.primary : AsoudColors.muted,
              size: 21),
        ),
      );
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice(
      {required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? color : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ),
      );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AsoudIconBox(
              icon: Icons.cloud_off_rounded,
              color: AsoudColors.warning,
              size: 52),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: context.read<WorkflowFormCubit>().load,
              child: const Text('تلاش دوباره')),
        ]),
      );
}

String _moduleLabel(String key) => switch (key) {
      'Purchase' => 'خرید',
      'Accounting' => 'مالی',
      'Sales' => 'فروش',
      'Inventory' => 'انبار',
      'Support' => 'پشتیبانی',
      'HR' => 'منابع انسانی',
      _ => key,
    };

String _doctypeLabel(String value) => switch (value) {
      'Material Request' => 'درخواست کالا',
      'Purchase Order' => 'سفارش خرید',
      'Payment Request' => 'درخواست پرداخت',
      'Expense Claim' => 'مطالبه هزینه',
      'Journal Entry' => 'سند حسابداری',
      'Quotation' => 'پیش‌فاکتور',
      'Sales Order' => 'سفارش فروش',
      'Stock Entry' => 'ورود و خروج انبار',
      'Issue' => 'درخواست پشتیبانی',
      'Leave Application' => 'درخواست مرخصی',
      'Job Applicant' => 'متقاضی استخدام',
      _ => value,
    };
