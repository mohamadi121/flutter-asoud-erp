import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../form_builder/form_repository.dart';
import '../../domain/entities/workflow_start_settings.dart';
import 'stage_form_source_picker.dart';

class WorkflowStartSection extends StatefulWidget {
  const WorkflowStartSection(
      {required this.value,
      required this.onChanged,
      required this.company,
      required this.roles,
      this.sourceSheetHeight,
      this.moduleKey = '',
      this.onModuleChanged,
      this.enabled = true,
      super.key});
  final WorkflowStartSettings value;
  final ValueChanged<WorkflowStartSettings> onChanged;
  final String company;
  final List<String> roles;
  final bool enabled;
  final double? Function()? sourceSheetHeight;
  final String moduleKey;
  final ValueChanged<String>? onModuleChanged;
  @override
  State<WorkflowStartSection> createState() => _WorkflowStartSectionState();
}

class _WorkflowStartSectionState extends State<WorkflowStartSection> {
  bool selecting = false;
  final additionalController = ExpansibleController();

  @override
  void dispose() {
    additionalController.dispose();
    super.dispose();
  }
  Future<void> pick() async {
    if (selecting || !widget.enabled) return;
    setState(() => selecting = true);
    try {
      FocusScope.of(context).unfocus();
      final measuredHeight = widget.sourceSheetHeight?.call();
      // Approximately 3 mm in the logical design; physical size varies by device.
      final height = measuredHeight == null ? null : (measuredHeight - 12).clamp(0.0, measuredHeight).toDouble();
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: height == null,
          showDragHandle: height == null,
          constraints: height == null ? null : BoxConstraints.tightFor(height: height),
          builder: (_) => StageFormSourcePicker(
              height: height, initialModule: widget.value.source == null ? '' : widget.moduleKey,
              repository: FormRepository(
                  context.read<FrappeApiClient>(), widget.company)));
      if (selected != null && mounted) {
        final module = selected['workflow_module'];
        if (module is String && module.isNotEmpty) widget.onModuleChanged?.call(module);
        widget.onChanged(widget.value.copyWith(source: selected));
      }
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  Future<void> roles() async {
    final chosen = widget.value.roles.toSet();
    final result = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheet) => StatefulBuilder(
            builder: (_, update) => SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .7,
                child: Column(children: [
                  const ListTile(title: Text('نقش‌های مجاز شروع دستی')),
                  Expanded(
                      child: ListView(children: [
                    for (final role in widget.roles
                        .where((r) => r != 'All' && r != 'Guest'))
                      CheckboxListTile(
                          title: Text(persianRoleLabel(role)),
                          value: chosen.contains(role),
                          onChanged: (checked) => update(() {
                                checked == true
                                    ? chosen.add(role)
                                    : chosen.remove(role);
                              }))
                  ])),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                          onPressed: chosen.isEmpty
                              ? null
                              : () => Navigator.pop(sheet, chosen.toList()),
                          child: const Text('تأیید نقش‌ها'))),
                ]))));
    if (result != null && mounted) {
      widget.onChanged(widget.value.copyWith(roles: result));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('نحوه شروع *',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          for (final manual in [false, true])
            Expanded(
                child: Padding(
              padding: EdgeInsetsDirectional.only(end: manual ? 0 : 8),
              child: InkWell(
                key: ValueKey(
                    manual ? 'workflow-start-manual' : 'workflow-start-form'),
                onTap: widget.enabled
                    ? () =>
                        widget.onChanged(widget.value.copyWith(manual: manual))
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: widget.value.manual == manual
                            ? const Color(0xffedf3ff)
                            : Colors.white,
                        border: Border.all(
                            color: widget.value.manual == manual
                                ? AsoudColors.primary
                                : AsoudColors.border),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                              widget.value.manual == manual
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: widget.value.manual == manual
                                  ? AsoudColors.primary
                                  : AsoudColors.muted,
                              size: 20),
                          const SizedBox(height: 8),
                          Text(manual ? 'شروع دستی' : 'با ارسال فرم',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              manual
                                  ? 'شروع با اقدام کاربر مجاز'
                                  : 'شروع خودکار پس از ارسال فرم',
                              style: const TextStyle(
                                  fontSize: 10, color: AsoudColors.muted)),
                        ])),
              ),
            ))
        ]),
        const SizedBox(height: 14),
        if (!widget.value.manual)
          Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                CheckboxListTile(
                    key: const ValueKey('workflow-select-source'),
                  controlAffinity: ListTileControlAffinity.leading,
                    value: widget.value.source != null,
                    onChanged:
                        widget.enabled && !selecting ? (_) => pick() : null,
                    secondary: const Icon(Icons.description_outlined,
                        color: AsoudColors.primary),
                    title: const Text('انتخاب درخواست یا سند',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        selecting
                            ? 'در حال دریافت…'
                            : '${widget.value.source?['title'] ?? 'نوع درخواست یا سند برای ورود به گردش کار'}',
                        style: const TextStyle(
                            fontSize: 11, color: AsoudColors.muted))),
                if (widget.value.source != null)
                  Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                          onPressed: widget.enabled
                              ? () => widget.onChanged(
                                  widget.value.copyWith(clearSource: true))
                              : null,
                          child: const Text('حذف انتخاب'))),
              ]))
        else
          Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                  title: const Text('نقش‌های مجاز شروع دستی'),
                  subtitle:
                      Text(widget.value.roles.map(persianRoleLabel).join('، ')),
                  trailing: const Icon(Icons.expand_more),
                  onTap: widget.enabled ? roles : null)),
        const SizedBox(height: 14),
        if (!widget.value.manual && widget.value.source != null) ...[
          AppSelectField(key: const ValueKey('workflow-source-route'),
            label: 'انتخاب گردش‌کار پس از ارسال فرم', value: widget.value.sourceRoute, enabled: widget.enabled,
            displayValue: const {'Available': 'فقط اتصال فرم', 'Default': 'گردش‌کار پیش‌فرض فرم',
              'Conditional': 'انتخاب بر اساس شرط شروع'}[widget.value.sourceRoute],
            onPick: () => showAppOptionSheet(context, title: 'انتخاب مسیر ارسال', current: widget.value.sourceRoute,
              options: const [AppOption('Available', 'فقط اتصال فرم'), AppOption('Default', 'گردش‌کار پیش‌فرض فرم'),
                AppOption('Conditional', 'انتخاب بر اساس شرط شروع')]),
            onChanged: (mode) => widget.onChanged(widget.value.withSourceRoute(mode))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
            widget.value.sourceRoute == 'Conditional'
              ? 'یک ایستگاه «شرط و مسیر» بلافاصله بعد از شروع قرار دهید. شرط آن فقط از اطلاعات فرم اصلی خوانده می‌شود؛ چند تطابق هم‌زمان خطای تعارض دارند.'
              : 'یک فرم می‌تواند در چند گردش‌کار استفاده شود. اولین اتصال، در نبود مسیر قبلی، پیش‌فرض می‌شود؛ اتصال‌های بعدی تا تعیین پیش‌فرض یا شرط، خودکار اجرا نمی‌شوند.',
            style: const TextStyle(fontSize: 11, color: AsoudColors.muted))),
        ],
        Card(
            margin: EdgeInsets.zero,
            key: const ValueKey('workflow-start-additional'),
            child: ExpansionTile(
                controller: additionalController,
                enabled: widget.enabled,
                leading: const AsoudIconBox(icon: Icons.tune_rounded,
                    color: AsoudColors.primary, size: 34),
                title: const Text('تنظیمات اضافی (اختیاری)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('کنترل شروع و سوابق گردش کار',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                children: [WorkflowStartAdditionalFields(value: widget.value,
                    enabled: widget.enabled, onConfirmed: (value) {
                      widget.onChanged(value);
                      additionalController.collapse();
                    })])),
      ]);
}

class WorkflowStartAdditionalFields extends StatefulWidget {
  const WorkflowStartAdditionalFields({required this.value, required this.onConfirmed,
      this.enabled = true, super.key});
  final WorkflowStartSettings value;
  final ValueChanged<WorkflowStartSettings> onConfirmed;
  final bool enabled;
  @override
  State<WorkflowStartAdditionalFields> createState() =>
      _WorkflowStartAdditionalFieldsState();
}

class _WorkflowStartAdditionalFieldsState
    extends State<WorkflowStartAdditionalFields> {
  late bool exception = widget.value.allowManagerRestart;
  Widget notice(String text, {Color color = AsoudColors.primary}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xfff4f7fc),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16)),
                child: Text(text.split('\n').first,
                    style: TextStyle(fontSize: 9, color: color)))),
        const SizedBox(height: 7),
        Text(text.split('\n').skip(1).join('\n'),
            style: const TextStyle(
                fontSize: 10, height: 1.8, color: AsoudColors.muted)),
      ]));
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(side: const BorderSide(color: AsoudColors.border),
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ExpansionTile(
                          enabled: widget.enabled,
                          trailing: const _StartPolicyArrow(),
                          initiallyExpanded: true,
                          title: const Text('۱. جلوگیری از شروع تکراری',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'جلوگیری از ایجاد چند نمونه فعال برای یک درخواست یا سند.',
                              style: TextStyle(fontSize: 10)),
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                        notice(
                            'فعال\nبه ازای هر درخواست یا سند، شروع هم‌زمان برای همان رکورد مسدود است.',
                            color: AsoudColors.success)
                      ]),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  ExpansionTile(
                          enabled: widget.enabled,
                          trailing: const _StartPolicyArrow(),
                          initiallyExpanded: true,
                          title: const Text(
                              '۲. جلوگیری از شروع مجدد پس از خاتمه',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'کنترل شروع دوباره برای رکوردهایی که گردش کارشان خاتمه یافته است.',
                              style: TextStyle(fontSize: 10)),
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                        notice(
                            'محدودیت فعال\nشروع مجدد پس از خاتمه برای همان رکورد مسدود می‌شود.',
                            color: AsoudColors.warning),
                        CheckboxListTile(
                            key: const ValueKey('workflow-manager-restart'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('استثناء برای مدیر مجاز',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: const Text(
                                'اجازه شروع مجدد با مجوز مدیریتی و ثبت علت',
                                style: TextStyle(fontSize: 10)),
                            value: exception,
                            onChanged: !widget.enabled ? null : (checked) =>
                                setState(() => exception = checked == true)),
                      ]),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  ExpansionTile(
                          enabled: widget.enabled,
                          trailing: const _StartPolicyArrow(),
                          initiallyExpanded: true,
                          title: const Text('۳. الزام ثبت علت شروع دستی',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'شفاف‌سازی اقدام آغازکننده گردش کار',
                              style: TextStyle(fontSize: 10)),
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                        notice(
                            'فقط شروع دستی\nعلت شروع توسط آغازکننده در زمان شروع واقعی وارد می‌شود.'),
                        const TextField(
                            enabled: false,
                            maxLines: 2,
                            decoration: InputDecoration(
                                labelText: 'علت شروع گردش کار *',
                                hintText: 'علت شروع دستی را وارد کنید…')),
                        const SizedBox(height: 12),
                      ]),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  ListTile(
                          leading: const Icon(Icons.verified_user_outlined,
                              color: AsoudColors.success),
                          title: const Text('۴. ثبت سوابق آغاز گردش کار',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'ثبت ایجادکننده، زمان شروع و شناسه گردش کار.',
                              style: TextStyle(fontSize: 10)),
                          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: AsoudColors.success.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Text('همیشه فعال',
                                  style: TextStyle(fontSize: 10, color: AsoudColors.success)))),
            Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff191919),
                            minimumSize: const Size.fromHeight(42), shape: const StadiumBorder()),
                        onPressed: !widget.enabled ? null : () => widget.onConfirmed(
                            widget.value.copyWith(allowManagerRestart: exception)),
                        child: const Text('تأیید تنظیمات اضافی')))),
          ])));
}

class _StartPolicyArrow extends StatelessWidget {
  const _StartPolicyArrow();
  @override
  Widget build(BuildContext context) => const CircleAvatar(radius: 8,
      backgroundColor: Color(0xff191919),
      child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 13));
}
