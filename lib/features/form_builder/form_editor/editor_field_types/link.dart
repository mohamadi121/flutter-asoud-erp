import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../../form_runtime.dart';
import '../editor_widgets.dart';

Widget? buildLinkSourceConfig(
  FormMap f,
  void Function(String key, dynamic value) set,
) {
  if (f['type'] != 'Link') {
    return null;
  }
  return formSelect(
    'منبع اطلاعات',
    f['source'] as String?,
    formSources,
    (v) => set('source', v),
  );
}

List<Widget> buildLinkAdvancedConfig({
  required FormMap f,
  required Map<String, String> fieldOptions,
  required void Function(String key, dynamic value) set,
  required void Function(VoidCallback fn) update,
}) {
  if (f['type'] != 'Link') {
    return const [];
  }
  return [
    formSelect(
      'فیلتر وابسته منبع',
      '${formMap(f['link_filter'])['field'] ?? ''}',
      {'': 'بدون فیلتر', ...?formLinkFilters[f['source']]},
      (v) => update(() {
        if (v.isEmpty) {
          f.remove('link_filter');
        } else {
          f['link_filter'] = {
            ...formMap(f['link_filter']),
            'field': v,
          };
        }
      }),
    ),
    if (f['link_filter'] != null)
      formSelect(
        'مقدار فیلتر از فیلد',
        formMap(f['link_filter'])['value_field'] as String?,
        fieldOptions,
        (v) => set(
          'link_filter',
          {...formMap(f['link_filter']), 'value_field': v},
        ),
      ),
  ];
}
