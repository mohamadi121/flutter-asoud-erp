import 'package:flutter/material.dart';

import '../form_repository.dart';
import 'field_inputs/choice_inputs.dart';
import 'field_inputs/date_time_inputs.dart';
import 'field_inputs/file_inputs.dart';
import 'field_inputs/link_inputs.dart';
import 'field_inputs/readonly_display_inputs.dart';
import 'field_inputs/text_number_inputs.dart';
import 'formula_engine.dart';
import 'rules_engine.dart';
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
  'LongText': 'متن چندخطی',
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1876D2),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final field in formMaps(section['fields']))
              if (formFlag(field, schema, computed, 'visible'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _input(context, field, computed),
                ),
          ],
        ),
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
      return readonlyWidget;
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
      return choiceWidget;
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
      return tableWidget;
    }

    final dateTimeWidget = buildDateTimeInput(
      context: context,
      f: f,
      value: v,
      label: label,
      required: required,
      onChanged: set,
    );
    if (dateTimeWidget != null) {
      return dateTimeWidget;
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
      return linkWidget;
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
      return fileWidget;
    }

    return buildTextNumberInput(
      f: f,
      value: v,
      label: label,
      required: required,
      onChanged: set,
    )!;
  }
}
