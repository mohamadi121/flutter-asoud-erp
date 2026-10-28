import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_template_repository.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_form_cubit.dart';
import '../widgets/workflow_template_picker.dart';
import 'workflow_designer_page.dart';

class WorkflowFormPage extends StatelessWidget {
  const WorkflowFormPage({this.existing, super.key});
  final WorkflowDefinition? existing;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          FrappeApiClient? client;
          try { client = context.read<FrappeApiClient>(); } on ProviderNotFoundException { /* injected test/preview tree */ }
          return WorkflowFormCubit(
          repository: context.read<WorkflowRepository>(),
          existing: existing,
          templates: client == null ? null : WorkflowTemplateRepository(client),
        )..load(); },
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
            if (context.read<WorkflowFormCubit>().existing != null) {
              Navigator.of(context).pop();
              return;
            }
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
            backgroundColor: const Color(0xfff7f9fd),
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
              title: Column(children: [
                Text(
                    context.read<WorkflowFormCubit>().existing == null
                        ? 'ایجاد گردش کار'
                        : 'تنظیمات گردش کار',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('اطلاعات پایه فرایند را وارد کنید',
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
                              : context.read<WorkflowFormCubit>().existing != null
                                  ? 'ذخیره تغییرات'
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

class _FormContent extends StatefulWidget {
  const _FormContent({required this.state});
  final WorkflowFormState state;
  @override
  State<_FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<_FormContent> {
  WorkflowFormState get state => widget.state;
  late final title = TextEditingController(text: state.title);
  late final description = TextEditingController(text: state.description);
  @override
  void didUpdateWidget(covariant _FormContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedTemplate?.id != state.selectedTemplate?.id) {
      title.text = state.title;
      description.text = state.description;
    }
  }
  @override
  void dispose() { title.dispose(); description.dispose(); super.dispose(); }

  Future<void> _more(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<WorkflowFormCubit>();
    final mode = await showModalBottomSheet<String>(
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(
                      child: Text('روش ایجاد گردش کار',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: 'بستن تنظیمات',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                  child: BlocBuilder<WorkflowFormCubit, WorkflowFormState>(
                      builder: (context, state) =>
                          _CreationModeOptions(state: state))),
            ]),
          ),
        ),
      ),
    );
    if (!context.mounted || cubit.isClosed || mode == null) return;
    if (mode == 'Custom') { cubit.changeCreationMode(mode); return; }
    if (cubit.templates == null || state.offlinePreview) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('انتخاب الگوی واقعی نیازمند ورود به سرور است.')));
      return;
    }
    final selected = await showModalBottomSheet<WorkflowTemplate>(context: context,
      isScrollControlled: true, useSafeArea: true, showDragHandle: true,
      builder: (_) => WorkflowTemplatePicker(repository: cubit.templates!, company: state.company,
          modules: state.options!.modules, selected: state.selectedTemplate));
    if (mounted && !cubit.isClosed && selected != null) cubit.selectTemplate(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkflowFormCubit>();
    final enabled = state.status != WorkflowFormStatus.submitting;
    return ListView(
      key: const ValueKey('workflow-form-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (state.offlinePreview) ...[
          const AsoudOfflinePreviewBanner(),
          const SizedBox(height: 12),
        ],
        _WorkflowSection(title: 'مشخصات گردش کار', icon: Icons.subject_rounded, children: [
        TextFormField(
          key: const ValueKey('workflow-title'),
          controller: title,
          enabled: enabled,
          hintLocales: const [Locale('fa')],
          onChanged: cubit.changeTitle,
          decoration: InputDecoration(
            labelText: 'عنوان گردش کار *',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'مثلاً تأیید درخواست تأمین کالا',
            errorText: state.titleError,
          ),
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          key: ValueKey('workflow-module-${state.moduleKey}'),
          isExpanded: true,
          initialValue: state.moduleKey.isEmpty ? null : state.moduleKey,
          decoration:
              const InputDecoration(labelText: 'ماژول *',
                  floatingLabelBehavior: FloatingLabelBehavior.always),
          items: state.options!.modules
              .map((item) => DropdownMenuItem(
                  value: item.key,
                  child: Text(_moduleLabel(item.key),
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: enabled && state.creationMode != 'Template' ? cubit.changeModule : null,
        ),
        const SizedBox(height: 22),
        TextFormField(
          key: const ValueKey('workflow-description'),
          controller: description,
          enabled: enabled,
          hintLocales: const [Locale('fa')],
          onChanged: cubit.changeDescription,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
              labelText: 'توضیح کوتاه (اختیاری)',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'هدف و کاربرد این گردش کار را بنویسید…',
              alignLabelWithHint: true),
        ),
        ]),
        const SizedBox(height: 14),
        _WorkflowSection(title: 'تنظیمات ظاهری', icon: Icons.palette_outlined,
            children: [_AppearanceSettings(state: state)]),
        const SizedBox(height: 14),
        if (cubit.existing == null)
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('workflow-more'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading:
                const Icon(Icons.settings_outlined, color: AsoudColors.primary),
            title: const Text('روش ایجاد گردش کار',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                state.creationMode == 'Template'
                    ? 'الگو: ${state.selectedTemplate?.title ?? 'انتخاب نشده'}'
                    : 'طراحی گردش کار جدید',
                style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.expand_more),
            onTap: enabled ? () => _more(context) : null,
          ),
        ),
        const SizedBox(height: 14),
        const _InfoBanner(icon: Icons.info_outline,
            text: 'گردش کار ابتدا به‌صورت پیش‌نویس ذخیره می‌شود؛ طراحی و تکمیل مراحل در صفحهٔ بعد انجام می‌شود.',
            color: AsoudColors.primary),
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

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AsoudColors.border)),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [AsoudIconBox(icon: icon, color: AsoudColors.primary, size: 35),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 24),
          ...children,
        ])));
}

class _CreationModeOptions extends StatelessWidget {
  const _CreationModeOptions({required this.state});
  final WorkflowFormState state;
  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, children: [
    for (final mode in const [('Custom', 'طراحی گردش کار جدید', Icons.edit_note_rounded),
        ('Template', 'استفاده از الگوی آماده', Icons.dashboard_customize_outlined)])
      ListTile(key: ValueKey('workflow-mode-${mode.$1}'),
        leading: Icon(mode.$3, color: AsoudColors.primary),
        title: Text(mode.$2),
        trailing: Icon(state.creationMode == mode.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
            color: state.creationMode == mode.$1 ? AsoudColors.primary : AsoudColors.muted),
        onTap: () => Navigator.pop(context, mode.$1)),
  ]);
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.state});
  final WorkflowFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkflowFormCubit>();
    final enabled = state.status != WorkflowFormStatus.submitting;
    final color = Color(int.tryParse(state.colorHex.replaceFirst('#', 'ff'), radix: 16) ?? 0xff315cf5);
    final icon = switch (state.iconKey) {
      'purchase' => Icons.shopping_cart_outlined,
      'expense' => Icons.account_balance_wallet_outlined,
      'support' => Icons.support_agent_outlined,
      'leave' => Icons.description_outlined,
      'hiring' => Icons.person_add_alt_1_outlined,
      _ => Icons.hub_outlined,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('آیکون گردش کار',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final option in const [
              ('hub', Icons.hub_outlined),
              ('purchase', Icons.shopping_cart_outlined),
              ('expense', Icons.account_balance_wallet_outlined),
              ('support', Icons.support_agent_outlined),
              ('leave', Icons.description_outlined),
              ('hiring', Icons.person_add_alt_1_outlined),
            ])
              Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: 5), child: _IconChoice(
                key: ValueKey('workflow-icon-${option.$1}'),
                icon: option.$2,
                selected: state.iconKey == option.$1,
                onTap: enabled ? () => cubit.changeIcon(option.$1) : null,
              ))),
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
                onTap: enabled ? () => cubit.changeColor(option.$1) : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xfff8fafe),
              borderRadius: BorderRadius.circular(12), border: Border.all(color: AsoudColors.border)),
          child: Row(children: [AsoudIconBox(icon: icon, color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('پیش‌نمایش کارت گردش کار', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(state.title.trim().isEmpty ? 'عنوان گردش کار' : state.title,
                  style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
            ]))])),
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
  final VoidCallback? onTap;
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
  final VoidCallback? onTap;
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
