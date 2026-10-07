import 'dart:convert';
import 'dart:io';

import 'package:asoud_erp/features/request_templates/data/system_templates.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(
      File('test/fixtures/request_templates/system_templates.json')
          .readAsStringSync()) as Map<String, dynamic>;

  for (final key in SystemTemplateKeys.all) {
    test('client $key field definitions equal the shared contract fixture', () {
      expect(jsonDecode(jsonEncode(systemTemplateFields(key))), fixture[key]);
    });
  }

  for (final key in SystemTemplateKeys.all) {
    test('the shared field model keeps every $key attribute', () {
      for (final raw in fixture[key] as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final round = WorkflowFormFieldDefinition.fromMap(map).toMap();
        // `toMap` always adds `required` and `options`; everything the
        // contract defines must survive the round trip unchanged.
        for (final entry in map.entries) {
          expect(round[entry.key], entry.value,
              reason: '$key.${map['key']}.${entry.key}');
        }
      }
    });
  }

  test('fixture holds exactly the three system templates', () {
    expect(fixture.keys.toList(), ['purchase', 'supply', 'leave']);
    expect([for (final k in fixture.keys) (fixture[k] as List).length],
        [10, 11, 14]);
  });

  test('request type rows resolve defaults and required_by_setting', () {
    final purchase = systemRequestType('purchase', costCenterRequired: true);
    final fields = {
      for (final f in purchase['fields'] as List)
        (f as Map)['key']: f.cast<String, dynamic>()
    };
    expect(fields['cost_center']!['required'], true);
    expect(fields['cost_center']!.containsKey('required_by_setting'), isFalse);
    expect(fields['requester']!['default_value'], 'ali@asoud.test');
    expect(fields['requester']!['default_label'], 'علی محمدی');
    expect(fields['requester']!.containsKey('default_source'), isFalse);
    expect(purchase['number_prefix'], 'PR');
    expect(purchase['subject_mode'], 'input');
    expect(
        (systemRequestType('purchase', costCenterRequired: false)['fields']
                as List)
            .cast<Map>()
            .firstWhere((f) => f['key'] == 'cost_center')['required'],
        false);
    final leave = systemRequestType('leave');
    expect(leave['subject_mode'], 'generated');
    expect((leave['attachments'] as Map)['extensions'],
        ['jpg', 'jpeg', 'png', 'pdf', 'docx']);
  });
}
