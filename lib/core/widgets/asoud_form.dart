import 'package:flutter/material.dart';
import '../theme/asoud_colors.dart';
import 'asoud_ui.dart';

/// Canonical form contract, extracted unchanged from PartyFormPage.
/// Keep all create/edit forms on these components; see docs/form-style.md.
abstract final class AsoudFormStyle {
  static const pagePadding = EdgeInsets.fromLTRB(16, 10, 16, 28);
  static const fieldPadding = EdgeInsets.only(bottom: 9);
  static const sectionMargin = EdgeInsets.only(bottom: 12);
  static const sectionPadding = EdgeInsets.fromLTRB(12, 0, 12, 12);
  static const sectionTitle =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w900);
  static const inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AsoudColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AsoudColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AsoudColors.border),
    ),
  );
}

class AsoudFormSection extends StatelessWidget {
  const AsoudFormSection(
      {required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        margin: AsoudFormStyle.sectionMargin,
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: AsoudFormStyle.sectionPadding,
          title: Text(title, style: AsoudFormStyle.sectionTitle),
          children: children,
        ),
      );
}

class AsoudFormField extends StatelessWidget {
  const AsoudFormField(
      {required this.controller,
      required this.label,
      this.validator,
      this.lines = 1,
      this.keyboardType,
      this.enabled = true,
      this.hint,
      this.suffixIcon,
      this.readOnly = false,
      this.onTap,
      super.key});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final int lines;
  final TextInputType? keyboardType;
  final bool enabled, readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: AsoudFormStyle.fieldPadding,
        child: TextFormField(
            controller: controller,
            maxLines: lines,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            decoration: InputDecoration(
                labelText: label, hintText: hint, suffixIcon: suffixIcon),
            validator: validator),
      );
}

class AsoudFormDropdown extends StatelessWidget {
  const AsoudFormDropdown(
      {required this.controller,
      required this.label,
      required this.options,
      this.required = false,
      this.enabled = true,
      super.key});
  final TextEditingController controller;
  final String label;
  final Map<String, String> options;
  final bool required, enabled;
  @override
  Widget build(BuildContext context) {
    final choices = {
      ...options,
      if (controller.text.isNotEmpty && !options.containsKey(controller.text))
        controller.text: controller.text
    };
    return Padding(
        padding: AsoudFormStyle.fieldPadding,
        child: DropdownButtonFormField<String>(
          initialValue: controller.text.isEmpty ? null : controller.text,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final e in choices.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value))
          ],
          onChanged: enabled ? (v) => controller.text = v ?? '' : null,
          validator: required
              ? (v) => v == null || v.isEmpty ? 'این فیلد الزامی است.' : null
              : null,
        ));
  }
}

String? asoudDateValidator(String? value, {bool required = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty && !required) return null;
  final date = DateTime.tryParse(text);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      date == null ||
      date.toIso8601String().substring(0, 10) != text) {
    return 'تاریخ معتبر به شکل YYYY-MM-DD وارد کنید.';
  }
  return null;
}

class AsoudFormDateField extends StatelessWidget {
  const AsoudFormDateField(
      {required this.controller,
      required this.label,
      this.required = false,
      this.enabled = true,
      super.key});
  final TextEditingController controller;
  final String label;
  final bool required, enabled;
  @override
  Widget build(BuildContext context) => AsoudFormField(
        controller: controller,
        label: label,
        enabled: enabled,
        keyboardType: TextInputType.datetime,
        hint: 'YYYY-MM-DD',
        validator: (v) => asoudDateValidator(v, required: required),
        suffixIcon: IconButton(
            tooltip: 'انتخاب تاریخ',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: !enabled
                ? null
                : () async {
                    final first = DateTime(1900), last = DateTime(2100, 12, 31);
                    final parsed =
                        DateTime.tryParse(controller.text) ?? DateTime.now();
                    final value = await showDatePicker(
                        context: context,
                        initialDate:
                            parsed.isBefore(first) || parsed.isAfter(last)
                                ? DateTime.now()
                                : parsed,
                        firstDate: first,
                        lastDate: last,
                        helpText: label);
                    if (value != null) {
                      controller.text =
                          value.toIso8601String().substring(0, 10);
                    }
                  }),
      );
}

class AsoudFormPage extends StatelessWidget {
  const AsoudFormPage(
      {required this.title,
      required this.formKey,
      required this.children,
      required this.onSave,
      this.saving = false,
      this.error,
      this.subtitle = 'تکمیل اطلاعات',
      this.saveLabel = 'ذخیره',
      super.key});
  final String title, subtitle, saveLabel;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final String? error;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
          canPop: !saving,
          child: Scaffold(
            appBar: AsoudHeader(title: title, subtitle: subtitle),
            body: SafeArea(
                child: Form(
                    key: formKey,
                    child: ListView(
                        padding: AsoudFormStyle.pagePadding,
                        children: [
                          ...children,
                          if (error != null)
                            Semantics(
                                liveRegion: true,
                                child: Text(error!,
                                    style: const TextStyle(
                                        color: AsoudColors.danger,
                                        fontSize: 11))),
                        ]))),
            bottomNavigationBar: AsoudBottomActions(
              primaryLabel: saving ? 'در حال ذخیره...' : saveLabel,
              onPrimary: saving ? null : onSave,
              secondaryLabel: 'انصراف',
              onSecondary: saving ? null : () => Navigator.pop(context),
            ),
          )));
}
