import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/record_links.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_equipment.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_traffic_correction.dart';

void main() {
  test('انتخاب رکورد تردد ساعت ورود و خروج فعلی را پر می‌کند و تغییر تاریخ آن را پاک می‌کند', () {
    final schema = hrTrafficCorrectionPreset();
    final picked = applyFieldChange(schema, {'attendance_date': '2026-10-12'},
        'attendance_record', 'HR-ATT-1', extra: {
      'in_time': '2026-10-12 08:30:00',
      'out_time': '2026-10-12 17:00:00',
    });
    expect(picked['current_in_time'], '08:30');
    expect(picked['current_out_time'], '17:00');
    final changed = applyFieldChange(schema, picked, 'attendance_date', '2026-10-13');
    expect(changed['attendance_record'], isNull);
    expect(changed['current_in_time'], isNull);
  });

  test('ستون تجهیز در جدول عودت یکتاست و تکرار پیام فارسی می‌دهد', () {
    final fields = [
      for (final s in formMaps(hrEquipmentPreset()['sections'])) ...formMaps(s['fields'])
    ];
    final table = fields.singleWhere((f) => f['key'] == 'returnable_equipment');
    expect(
      uniqueColumnProblem(table, [
        {'equipment_reference': 'AST-1'},
        {'equipment_reference': 'AST-1'},
      ]),
      'ردیف تکراری: تجهیز در اختیار شما',
    );
    expect(uniqueColumnProblem(table, [
      {'equipment_reference': 'AST-1'},
      {'equipment_reference': 'AST-2'},
    ]), isNull);
  });
}
