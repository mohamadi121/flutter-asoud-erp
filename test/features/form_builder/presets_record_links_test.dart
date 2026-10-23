import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_employment_certificate.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_salary_advance.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_settlement.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_shift_change.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_training.dart';

import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/record_links.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_equipment.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_traffic_correction.dart';

void main() {
  _widgetTests();
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

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
}

/// Answers `forms.get_link_options` with the real `{name, label, extra}` rows.
class _Repository extends FormRepository {
  _Repository(this.rows) : super(_Client(), 'شرکت نمونه آسود');
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<FormMap> callEnvelope(String method, [FormMap data = const {}]) async {
    expect(method, 'get_link_options');
    requests.add(data);
    return {'ok': true, 'data': rows, 'meta': <String, dynamic>{}};
  }
}

class _Host extends StatefulWidget {
  const _Host(this.schema, this.repository, this.initial, this.formKey, this.log);
  final FormMap schema;
  final FormRepository repository;
  final FormMap initial;
  final GlobalKey<FormState> formKey;
  final List<FormMap> log;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late FormMap values = widget.initial;
  @override
  Widget build(BuildContext context) => Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: FormFieldsView(
            schema: widget.schema,
            values: values,
            repository: widget.repository,
            onChanged: (next) {
              widget.log.add(next);
              setState(() => values = next);
            },
          ),
        ),
      );
}

Future<void> _pump(WidgetTester tester, double width, FormMap schema,
    _Repository repo, FormMap initial, GlobalKey<FormState> key, List<FormMap> log) async {
  tester.view.physicalSize = Size(width, width < 400 ? 640 : 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: _Host(schema, repo, initial, key, log)),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String label, String rowLabel) async {
  final tile = find.text(label);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  await tester.tap(find.text(rowLabel));
  await tester.pumpAndSettle();
}

const _sizes = [320.0, 390.0, 430.0];

void _widgetTests() {
  final presets = {
    'traffic': hrTrafficCorrectionPreset,
    'shift': hrShiftChangePreset,
    'settlement': hrSettlementPreset,
    'training': hrTrainingPreset,
    'equipment': hrEquipmentPreset,
    'advance': hrSalaryAdvancePreset,
    'certificate': employmentCertificatePreset,
  };
  for (final width in _sizes) {
    for (final e in presets.entries) {
      testWidgets('الگوی ${e.key} در ${width.toInt()} پیکسل راست‌به‌چپ بدون خطا نمایش داده می‌شود',
          (tester) async {
        final key = GlobalKey<FormState>();
        await _pump(tester, width, e.value(), _Repository(const []), {}, key, []);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('اصلاح تردد ${width.toInt()}: انتخاب رکورد، فیلتر تاریخ و ساعت یکسان',
        (tester) async {
      final repo = _Repository([
        {
          'name': 'HR-ATT-1',
          'label': 'رکورد نمونه',
          'extra': {
            'in_time': '2026-10-12 08:30:00',
            'out_time': '2026-10-12 17:00:00',
            'attendance_date': '2026-10-12',
            'status': 'Present',
            'shift': 'روز',
          },
        }
      ]);
      final key = GlobalKey<FormState>();
      final log = <FormMap>[];
      await _pump(tester, width, hrTrafficCorrectionPreset(), repo, {
        'correction_type': 'correct_recorded_time',
        'recorded_event': 'check_in',
        'attendance_date': '2026-10-12',
        'correction_reason': 'نادرست',
      }, key, log);
      await _pick(tester, 'رکورد تردد *', 'رکورد نمونه');
      expect(repo.requests.single['source'], 'Attendance');
      expect(repo.requests.single['filter_field'], 'attendance_date');
      expect(repo.requests.single['filter_value'], '2026-10-12');
      expect(log.last['attendance_record'], 'HR-ATT-1');
      expect(log.last['current_in_time'], '08:30');
      expect(find.text('ساعت خروج ثبت‌شده فعلی'), findsNothing);
      expect(find.text('ساعت ورود ثبت‌شده فعلی'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, width, hrTrafficCorrectionPreset(), repo, {
        ...log.last,
        'proposed_correct_in_time': '08:30',
      }, key, []);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('ساعت پیشنهادی با ساعت ثبت‌شده فعلی یکسان است.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, width, hrTrafficCorrectionPreset(), repo, {
        ...log.last,
        'proposed_correct_in_time': '09:00',
      }, key, []);
      key.currentState!.validate();
      await tester.pump();
      expect(find.text('ساعت پیشنهادی با ساعت ثبت‌شده فعلی یکسان است.'), findsNothing);
    });

    testWidgets('تغییر شیفت ${width.toInt()}: خود کاربر از همکار حذف و شیفت درخواستی از نوع شیفت',
        (tester) async {
      final repo = _Repository([
        {'name': 'EMP-2', 'label': 'همکار نمونه', 'extra': {'department': 'D', 'designation': 'X', 'employee_number': '12'}},
      ]);
      final key = GlobalKey<FormState>();
      final log = <FormMap>[];
      await _pump(tester, width, hrShiftChangePreset(), repo,
          {'change_type': 'swap_with_colleague'}, key, log);
      await _pick(tester, 'همکار طرف جابه‌جایی *', 'همکار نمونه');
      expect(repo.requests.single['source'], 'Employee');
      expect(repo.requests.single['exclude_self'], 1);
      expect(log.last['exchange_colleague'], 'EMP-2');
    });

    testWidgets('آموزش ${width.toInt()}: انتخاب دوره ساعت و نوع را پر می‌کند',
        (tester) async {
      final repo = _Repository([
        {
          'name': 'TE-1',
          'label': 'دوره نمونه',
          'extra': {'start_time': '2026-11-01 09:00:00', 'end_time': '2026-11-01 13:00:00', 'type': 'Seminar', 'level': 'L', 'training_program': 'P'},
        }
      ]);
      final key = GlobalKey<FormState>();
      final log = <FormMap>[];
      await _pump(tester, width, hrTrainingPreset(), repo, {'request_type': 'existing_course'}, key, log);
      await _pick(tester, 'دوره آموزشی *', 'دوره نمونه');
      expect(repo.requests.single['source'], 'Training Event');
      expect(log.last['course_start_time'], '09:00');
      expect(log.last['course_end_time'], '13:00');
      expect(log.last['course_type'], 'Seminar');
    });

    testWidgets('تجهیزات ${width.toInt()}: دارایی تکراری در جدول عودت رد می‌شود',
        (tester) async {
      final key = GlobalKey<FormState>();
      await _pump(tester, width, hrEquipmentPreset(), _Repository(const []), {
        'equipment_request_type': 'return_equipment',
        'returnable_equipment': [
          {'equipment_reference': 'AST-1', 'quantity': 1, 'reported_condition': 'healthy'},
          {'equipment_reference': 'AST-1', 'quantity': 1, 'reported_condition': 'healthy'},
        ],
      }, key, []);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('ردیف تکراری: تجهیز در اختیار شما'), findsOneWidget);
    });
  }

  test('کد پرسنلی تسویه‌حساب از منبع خودکار می‌آید نه مقدار ثابت', () {
    final f = schemaFields(hrSettlementPreset()).singleWhere((f) => f['key'] == 'applicant_code');
    expect(f['default_source'], 'employee_number');
    expect(f.containsKey('default'), isFalse);
  });
}
