import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';

import '../form_repository.dart';
import 'field_inputs/choice_inputs.dart';
import 'field_inputs/date_time_inputs.dart';
import 'field_inputs/file_inputs.dart';
import 'field_inputs/link_inputs.dart';
import 'field_inputs/readonly_display_inputs.dart';
import 'field_inputs/text_number_inputs.dart';
import 'formula_engine.dart';
import 'rules_engine.dart';
import 'section_colors.dart';
import 'table_field.dart';

export 'field_inputs/choice_inputs.dart';
export 'field_inputs/date_time_inputs.dart';
export 'field_inputs/file_inputs.dart';
export 'field_inputs/link_inputs.dart';
export 'field_inputs/readonly_display_inputs.dart';
export 'field_inputs/text_number_inputs.dart';
export 'table_field.dart';

const formTypes = <String, String>{
  'Text': 'متن کوتاه',
  'LongText': 'متن بلند',
  'Integer': 'عدد صحیح',
  'Decimal': 'عدد اعشاری',
  'Money': 'مبلغ (ریال)',
  'Date': 'تاریخ',
  'Time': 'ساعت',
  'DateTime': 'تاریخ و ساعت',
  'Select': 'انتخاب تکی',
  'MultiSelect': 'چندانتخابی',
  'Checkbox': 'چک‌باکس',
  'Boolean': 'کلید دوحالته',
  'Link': 'اتصال به سیستم',
  'Table': 'جدول تکرارشونده',
  'Formula': 'محاسبه خودکار',
  'File': 'پیوست فایل',
  'Image': 'تصویر',
  'Signature': 'امضا',
  'Rating': 'امتیاز ۱ تا ۵',
  'Barcode': 'بارکد / شناسه',
  'Display': 'متن نمایشی',
};

const formSources = <String, String>{
  'Employee': 'پرسنل',
  'Department': 'واحد سازمانی',
  'Company': 'شرکت‌ها',
  'Customer': 'مشتریان',
  'Supplier': 'تأمین‌کنندگان',
  'Item': 'کالاها و خدمات',
  'Warehouse': 'انبارها',
  'Cost Center': 'مراکز هزینه',
  'Project': 'پروژه‌ها',
};

const formOps = <String, String>{
  'eq': 'برابر با',
  'ne': 'نامساوی',
  'gt': 'بزرگ‌تر از',
  'lt': 'کوچک‌تر از',
  'ge': 'بزرگ‌تر یا مساوی',
  'le': 'کوچک‌تر یا مساوی',
  'contains': 'شامل متن یا گزینه',
  'empty': 'خالی است',
  'not_empty': 'پر است',
};

const formulaOps = <String, String>{
  'add': 'جمع ورودی‌ها (+)',
  'sub': 'تفریق ورودی‌ها (-)',
  'mul': 'ضرب ورودی‌ها (×)',
  'div': 'تقسیم ورودی‌ها (÷)',
  'sum': 'جمع کل ستون جدول (SUM)',
  'count': 'تعداد ردیف‌های جدول (COUNT)',
  'avg': 'میانگین ستون جدول (AVG)',
  'min': 'کمترین مقدار ستون (MIN)',
  'max': 'بیشترین مقدار ستون (MAX)',
};

const formLinkFilters = <String, Map<String, String>>{
  'Employee': {
    'department': 'واحد سازمانی',
    'company': 'دفتر / شرکت',
  },
  'Item': {
    'item_group': 'گروه کالا',
  },
  'Warehouse': {
    'company': 'دفتر / شرکت',
  },
};

class FormFieldsView extends StatelessWidget {
  const FormFieldsView({
    required this.schema,
    required this.values,
    required this.onChanged,
    required this.repository,
    this.formName,
    this.enabled = true,
    this.snapshot = false,
    super.key,
  });

  final FormMap schema, values;
  final ValueChanged<FormMap> onChanged;
  final FormRepository repository;
  final String? formName;
  final bool enabled;
  final bool snapshot;

  @override
  Widget build(BuildContext context) {
    final computed = snapshot ? values : evaluatedValues(schema, values);
    final sections = formMaps(schema['sections']);

    Widget sectionView(FormMap section) {
      final title = '${section['title'] ?? ''}'.trim();
      final hasNewPresentation = ['icon', 'color', 'background_color', 'description', 'collapsible']
          .any((key) => section.containsKey(key));
      if (!hasNewPresentation) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title.isNotEmpty) ...[
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFEBF3FF), borderRadius: BorderRadius.circular(8)), child: Text(title, style: const TextStyle(color: Color(0xFF1876D2), fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(height: 12),
            ],
            _sectionFields(context, section, computed),
          ]),
        );
      }
      final description = '${section['description'] ?? ''}'.trim();
      final colors = sectionColors(section)!;
      final bg = colors.background;
      final accent = colors.accent;
      final icon = sectionIconForName('${section['icon'] ?? ''}');
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: StatefulBuilder(builder: (context, setSectionState) {
          var collapsed = section['collapsible'] == true && section['collapsed'] == true;
          return Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title.isNotEmpty) ...[
              InkWell(
                onTap: section['collapsible'] == true ? () => setSectionState(() {
                  section['collapsed'] = !collapsed;
                  collapsed = !collapsed;
                }) : null,
                child: Row(children: [
                  Icon(icon, color: accent, size: 20), const SizedBox(width: 8),
                  Expanded(child: Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13))),
                  if (section['collapsible'] == true) Icon(collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: accent),
                ]),
              ),
              if (description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
              const SizedBox(height: 12),
            ],
            if (!collapsed) _sectionFields(context, section, computed),
              ]),
            ),
          );
        }),
      );
    }

    if (schema['layout'] == 'tabs' && sections.length > 1) {
      return DefaultTabController(
        length: sections.length,
        child: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final section in sections)
                      Tab(text: '${section['title']}'),
                  ],
                ),
                AnimatedBuilder(
                  animation: tabs,
                  builder: (context, child) =>
                      sectionView(sections[tabs.index]),
                ),
              ],
            );
          },
        ),
      );
    }
    return Column(children: sections.map(sectionView).toList());
  }

  Widget _sectionFields(BuildContext context, FormMap section, FormMap computed) => LayoutBuilder(
    builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      const spacing = 12.0;
      final halfWidth = (totalWidth - spacing) / 2;
      final visibleFields = formMaps(section['fields']).where((field) => formFlag(field, schema, computed, 'visible')).toList();
      return Wrap(spacing: spacing, runSpacing: 12, children: [
        for (final field in visibleFields)
          SizedBox(width: (field['span'] as num?)?.toInt() == 1 ? halfWidth : totalWidth, child: _withHelp(field, _input(context, field, computed))),
      ]);
    },
  );

  Widget _input(BuildContext context, FormMap f, FormMap computed) {
    final key = '${f['key']}';
    final v = computed[key];
    final required = formFlag(f, schema, computed, 'required');
    final label = '${f['label']}${required ? ' *' : ''}';
    final editable = enabled && !formFlag(f, schema, computed, 'readonly');
    void set(dynamic value) => onChanged({...computed, key: value});

    final readonlyWidget = buildReadonlyDisplayInput(
      f: f,
      value: v,
      label: label,
      editable: editable,
    );
    if (readonlyWidget != null) {
      return _withAutomaticPlaceholder(f, v, readonlyWidget);
    }

    final choiceWidget = buildChoiceInput(
      context: context,
      f: f,
      value: v,
      label: label,
      required: required,
      onChanged: set,
    );
    if (choiceWidget != null) {
      return _withAutomaticPlaceholder(f, v, choiceWidget);
    }

    final tableWidget = buildTableField(
      context: context,
      f: f,
      value: v,
      label: label,
      editable: editable,
      snapshot: snapshot,
      repository: repository,
      formName: formName,
      onChanged: set,
    );
    if (tableWidget != null) {
      final minRows = (f['min_rows'] as num?)?.toInt() ?? 0;
      return _withAutomaticPlaceholder(f, v, FormField<dynamic>(
        validator: (_) {
          final count = formMaps(v).length;
          final needed = minRows > 0 ? minRows : (required ? 1 : 0);
          if (count < needed) {
            return 'حداقل ${toPersianDigits(needed)} ردیف لازم است.';
          }
          return null;
        },
        builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tableWidget,
          if (state.hasError) Padding(padding: const EdgeInsets.only(top: 4), child: Text(state.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ));
    }

    final dateTimeWidget = buildDateTimeInput(
      context: context,
      f: f,
      value: v,
      label: label,
      required: required,
      values: computed,
      onChanged: set,
    );
    if (dateTimeWidget != null) {
      return _withAutomaticPlaceholder(f, v, dateTimeWidget);
    }

    final linkWidget = buildLinkInput(
      context: context,
      f: f,
      computed: computed,
      value: v,
      label: label,
      repository: repository,
      formName: formName,
      onChanged: set,
    );
    if (linkWidget != null) {
      return _withAutomaticPlaceholder(f, v, linkWidget);
    }

    final fileWidget = buildFileInput(
      context: context,
      f: f,
      value: v,
      label: label,
      repository: repository,
      formName: formName,
      onChanged: set,
    );
    if (fileWidget != null) {
      return _withAutomaticPlaceholder(f, v, fileWidget);
    }

    final input = buildTextNumberInput(
      f: f,
      value: v,
      label: label,
      required: required,
      onChanged: set,
    )!;
    return _withAutomaticPlaceholder(f, v, input);
  }

  Widget _withHelp(FormMap field, Widget input) {
    final help = '${field['help'] ?? ''}'.trim();
    if (help.isEmpty || ['Text', 'LongText', 'Integer', 'Decimal', 'Money', 'Rating'].contains(field['type'])) return input;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [input, const SizedBox(height: 4), Text(help, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))]);
  }

  Widget _withAutomaticPlaceholder(FormMap field, dynamic value, Widget input) {
    if (value != null || '${field['default_source'] ?? ''}'.trim().isEmpty) return input;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      input,
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('دریافت خودکار', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ),
    ]);
  }
}

IconData sectionIconForName(String icon) => switch (icon) {
  'person' || 'employee' => Icons.person_outline,
  'event' || 'calendar' || 'schedule' || 'clock' => Icons.event_outlined,
  'description' || 'document' || 'assignment' || 'assignment_turned_in' || 'fact_check' => Icons.description_outlined,
  'payments' || 'money' => Icons.payments_outlined,
  'school' || 'training' => Icons.school_outlined,
  'inventory' || 'inventory_2' || 'equipment' || 'box' => Icons.inventory_2_outlined,
  'swap_horiz' => Icons.swap_horiz,
  'notes' || 'edit_note' => Icons.notes_outlined,
  'wallet' => Icons.account_balance_wallet_outlined,
  'badge' => Icons.badge_outlined,
  'download' => Icons.download_outlined,
  'account_tree' => Icons.account_tree_outlined,
  'attach_file' => Icons.attach_file_outlined,
  'receipt' => Icons.receipt_long_outlined,
  _ => Icons.folder_outlined,
};
