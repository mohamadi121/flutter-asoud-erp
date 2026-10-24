import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../../form_runtime/record_links.dart';
import '../editor_widgets.dart';

const _fetchTargetTypes = {
  'Text',
  'LongText',
  'Date',
  'Time',
  'DateTime',
  'Integer',
  'Decimal',
};

const _notEqualTypes = {
  'Text',
  'Integer',
  'Decimal',
  'Money',
  'Date',
  'Time',
  'Select',
};

/// «مقدار از فیلد»: first a Link field of the form, then one allowed attribute.
List<Widget> buildFetchFromConfig({
  required FormMap f,
  required List<FormMap> fields,
  required void Function(String key, dynamic value) set,
  required void Function(VoidCallback fn) update,
}) {
  if (!_fetchTargetTypes.contains(f['type'])) return const [];
  final links = {
    for (final field in fields)
      if (field['type'] == 'Link' && field['key'] != f['key'])
        '${field['key']}': field,
  };
  if (links.isEmpty) return const [];
  final parsed = parseFetchFrom(f['fetch_from']);
  final linkKey = parsed != null && links.containsKey(parsed.link)
      ? parsed.link
      : '';
  final source = linkKey.isEmpty ? null : '${links[linkKey]!['source'] ?? 'Employee'}';
  final attributes = source == null
      ? const <String, String>{}
      : formFetchAttributes[source] ?? const <String, String>{};
  return [
    formSelect(
      'مقدار از فیلد',
      linkKey,
      {
        '': 'ورود دستی',
        for (final e in links.entries) e.key: '${e.value['label']}',
      },
      (v) => update(() {
        if (v.isEmpty) {
          f.remove('fetch_from');
        } else {
          final attributes = formFetchAttributes[
                  '${links[v]?['source'] ?? 'Employee'}'] ??
              const <String, String>{};
          f['fetch_from'] = attributes.isEmpty ? v : '$v.${attributes.keys.first}';
        }
      }),
    ),
    if (linkKey.isNotEmpty)
      formSelect(
        'کدام اطلاعات',
        parsed?.attribute,
        attributes,
        (v) => set('fetch_from', '$linkKey.$v'),
      ),
  ];
}

List<Widget> buildNotEqualConfig({
  required FormMap f,
  required List<FormMap> fields,
  required void Function(String key, dynamic value) set,
}) {
  if (!_notEqualTypes.contains(f['type'])) return const [];
  return [
    formSelect(
      'نباید برابر با فیلد:',
      '${f['not_equal'] ?? ''}',
      {
        '': 'بدون محدودیت',
        for (final field in fields)
          if (field['key'] != f['key'] && field['type'] == f['type'])
            '${field['key']}': '${field['label']}',
      },
      (v) => set('not_equal', v.isEmpty ? null : v),
    ),
  ];
}

List<Widget> buildTimeAfterConfig({
  required FormMap f,
  required List<FormMap> fields,
  required void Function(String key, dynamic value) set,
}) {
  if (f['type'] != 'Time') return const [];
  return [
    formSelect(
      'باید بعد از فیلد:',
      '${f['time_after'] ?? ''}',
      {
        '': 'بدون محدودیت',
        for (final field in fields)
          if (field['key'] != f['key'] && field['type'] == 'Time')
            '${field['key']}': '${field['label']}',
      },
      (v) => set('time_after', v.isEmpty ? null : v),
    ),
  ];
}

Widget uniqueColumnSwitch(
  FormMap f,
  void Function(String key, dynamic value) set,
) =>
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('تکراری مجاز نیست', style: TextStyle(fontSize: 13)),
      value: f['unique'] == true,
      onChanged: (v) => set('unique', v ? true : null),
    );

List<Widget> buildCompareConfig({
  required FormMap f,
  required List<FormMap> fields,
  required void Function(String key, dynamic value) set,
}) {
  if (f['type'] != 'Display') return const [];
  final times = fields.where((field) => field['type'] == 'Time' && field['key'] != f['key']).toList();
  if (times.length < 2) return const [];
  final compare = formMap(f['compare']);
  final options = {'': 'انتخاب نشده', for (final field in times) '${field['key']}': '${field['label']}'};
  void update(String side, String value) {
    if (value.isEmpty) {
      set('compare', null);
      return;
    }
    final other = side == 'current' ? 'proposed' : 'current';
    final fallback = times.firstWhere((field) => field['key'] != value)['key'];
    set('compare', {...compare, side: value, other: compare[other] ?? fallback});
  }
  return [
    formSelect('ساعت ثبت‌شده', '${compare['current'] ?? ''}', options, (v) => update('current', v)),
    formSelect('ساعت پیشنهادی', '${compare['proposed'] ?? ''}', options, (v) => update('proposed', v)),
  ];
}
