import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkedPresetTitles = <String>{
  'درخواست اصلاح تردد',
  'درخواست مساعده',
  'درخواست گواهی اشتغال به کار',
  'درخواست تغییر شیفت',
  'درخواست آموزش کارکنان',
  'درخواست تحویل یا عودت تجهیزات',
  'درخواست تسویه‌حساب پرسنل',
  'درخواست مرخصی',
  'درخواست مأموریت',
  'درخواست اضافه‌کار',
};

const _schemaKeys = <String>{
  'schema_version', 'format', 'kind', 'title', 'module', 'icon', 'color',
  'description', 'sections', 'rules', 'access', 'layout',
};
const _sectionKeys = <String>{
  'id', 'title', 'description', 'icon', 'color', 'background_color',
  'collapsible', 'collapsed', 'fields',
};
const _fieldKeys = <String>{
  'key', 'label', 'type', 'required', 'readonly', 'span', 'help', 'source',
  'link_filter', 'default', 'default_source', 'options', 'style', 'min', 'max',
  'after_or_equal', 'after_or_equal_message', 'columns', 'min_rows', 'max_rows',
  'formula', 'min_length', 'max_length', 'extensions', 'max_files', 'max_mb',
  'error_message', 'format', 'minute_step', 'fetch_from', 'not_equal',
  'not_equal_message', 'exclude_self', 'unique', 'schedule_of', 'from_field',
  'to_field', 'compare', 'next_day_allowed', 'sensitive', 'before_or_equal',
  'before_or_equal_message', 'time_after', 'time_after_message',
};
const _ruleKeys = <String>{'target', 'action', 'join', 'conditions', 'enabled'};
const _conditionKeys = <String>{'field', 'op', 'value'};
const _sources = <String>{
  'Employee', 'Customer', 'Supplier', 'Item', 'Warehouse', 'Account',
  'Cost Center', 'Project', 'Department', 'Attendance', 'Shift Type',
  'Leave Type', 'Training Event', 'Asset',
};
const _defaultSources = <String>{
  'user', 'company', 'today', 'employee', 'department', 'designation',
  'joining_date', 'employee_number', 'default_shift', 'contract_start',
};

void main() {
  test('الگوهای بررسی‌شده فقط از قرارداد نسخه دو استفاده می‌کنند', () {
    final presets = formPresets('Request');
    final titles = presets.map((preset) => '${preset['title']}').toSet();
    expect(titles.containsAll(_checkedPresetTitles), isTrue);

    for (final preset in presets.where(
      (item) => _checkedPresetTitles.contains('${item['title']}'),
    )) {
      _expectOnlyKeys(preset, _schemaKeys, 'الگو ${preset['title']}');
      for (final section in formMaps(preset['sections'])) {
        _expectOnlyKeys(section, _sectionKeys, 'بخش ${section['id']}');
        for (final field in formMaps(section['fields'])) {
          _checkField(field, 'فیلد ${field['key']}');
        }
      }
      for (final rule in formMaps(preset['rules'])) {
        _expectOnlyKeys(rule, _ruleKeys, 'قانون ${rule['target']}');
        for (final condition in formMaps(rule['conditions'])) {
          _expectOnlyKeys(condition, _conditionKeys, 'شرط ${rule['target']}');
        }
      }
    }
  });
}

void _checkField(FormMap field, String context) {
  _expectOnlyKeys(field, _fieldKeys, context);
  if (field['type'] == 'Link') {
    expect(_sources, contains(field['source']), reason: context);
  }
  if (field.containsKey('default_source')) {
    expect(_defaultSources, contains(field['default_source']), reason: context);
  }
  for (final column in formMaps(field['columns'])) {
    _checkField(column, '$context / ستون ${column['key']}');
  }
}

void _expectOnlyKeys(FormMap value, Set<String> allowed, String context) {
  expect(value.keys.where((key) => !allowed.contains(key)), isEmpty, reason: context);
}
