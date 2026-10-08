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
        builder: (context, state) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 76,
              centerTitle: true,
              leading: IconButton(
                tooltip: 'بازگشت',
                onPressed: state.status == WorkflowFormStatus.submitting
                    ? null
                    : () => Navigator.maybePop(context),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              title: const Column(children: [
                Text('ایجاد گردش کار',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('اطلاعات پایه فرایند را وارد کنید',
                    style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
              ]),
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
                : Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: AsoudBottomActions(
                      primaryLabel:
                          state.status == WorkflowFormStatus.submitting
                              ? 'در حال ذخیره...'
                              : 'ذخیره و طراحی مراحل',
                      onPrimary: state.status == WorkflowFormStatus.submitting
                          ? null
                          : context.read<WorkflowFormCubit>().submit,
                    ),
                  ),
          ),
        ),
      );
}

class _FormContent extends StatelessWidget {
  const _FormContent({required this.state});
  final WorkflowFormState state;

  Future<void> _more(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<WorkflowFormCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: FractionallySizedBox(
            heightFactor: .82,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(
                      child: Text('تنظیمات بیشتر',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: 'بستن تنظیمات',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                  child: BlocBuilder<WorkflowFormCubit, WorkflowFormState>(
                      builder: (context, state) =>
                          _MoreSettingsContent(state: state))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkflowFormCubit>();
    final enabled = state.status != WorkflowFormStatus.submitting;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (state.offlinePreview) ...[
          const AsoudOfflinePreviewBanner(),
          const SizedBox(height: 12),
        ],
        const _FieldLabel('عنوان گردش کار *'),
        TextFormField(
          key: const ValueKey('workflow-title'),
          initialValue: state.title,
          enabled: enabled,
          onChanged: cubit.changeTitle,
          decoration: InputDecoration(
            hintText: 'مثلاً تأیید درخواست تأمین کالا',
            suffixIcon: const Icon(Icons.title_rounded),
            errorText: state.titleError,
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('ماژول *'),
        DropdownButtonFormField<String>(
          key: ValueKey('workflow-module-${state.moduleKey}'),
          isExpanded: true,
          initialValue: state.moduleKey.isEmpty ? null : state.moduleKey,
          decoration:
              const InputDecoration(suffixIcon: Icon(Icons.layers_outlined)),
          items: state.options!.modules
              .map((item) => DropdownMenuItem(
                  value: item.key,
                  child: Text(_moduleLabel(item.key),
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: enabled ? cubit.changeModule : null,
        ),
        const SizedBox(height: 22),
        const _FieldLabel('توضیح کوتاه (اختیاری)'),
        TextFormField(
          key: const ValueKey('workflow-description'),
          initialValue: state.description,
          enabled: enabled,
          onChanged: cubit.changeDescription,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'هدف و کاربرد این گردش کار را بنویسید…',
              suffixIcon: Icon(Icons.description_outlined)),
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('workflow-more'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading:
                const Icon(Icons.settings_outlined, color: AsoudColors.primary),
            title: const Text('تنظیمات بیشتر',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                state.creationMode == 'Template'
                    ? 'قالب پیشنهادی فعال • آیکون، رنگ و موارد تکمیلی'
                    : 'آیکون، رنگ و موارد تکمیلی',
                style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.expand_more),
            onTap: enabled ? () => _more(context) : null,
          ),
        ),
        if (state.message != null &&
            state.status == WorkflowFormStatus.ready) ...[
          const SizedBox(height: 12),
          Text(state.message!,
              style: const TextStyle(color: AsoudColors.warning)),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)));
}

class _MoreSettingsContent extends StatelessWidget {
  const _MoreSettingsContent({required this.state});
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text('آیکون گردش کار',
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
                key: ValueKey('workflow-icon-${option.$1}'),
                icon: option.$2,
                selected: state.iconKey == option.$1,
                onTap: () => cubit.changeIcon(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('رنگ گردش کار',
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
                key: ValueKey('workflow-color-${option.$1}'),
                color: option.$2,
                selected: state.colorHex == option.$1,
                onTap: () => cubit.changeColor(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('استفاده از قالب پیشنهادی',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: const Text(
              'قالب اولیه از مسیر فعلی پروژه ایجاد می‌شود؛ مراحل در صفحه بعد قابل تکمیل‌اند.',
              style: TextStyle(fontSize: 11)),
          value: state.creationMode == 'Template',
          onChanged: (value) =>
              cubit.changeCreationMode(value ? 'Template' : 'Custom'),
        ),
        const Divider(height: 32),
        const _FieldLabel('دامنه و سند مقصد'),
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
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey(
              'workflow-doctype-${state.moduleKey}-${state.targetDoctype}'),
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
      {required this.icon,
      required this.selected,
      required this.onTap,
      super.key});
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
      {required this.color,
      required this.selected,
      required this.onTap,
      super.key});
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
