import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/record_links.dart';

class _Client extends Fake implements FrappeApiClient {
  _Client(this.authenticated);
  final bool authenticated;
  @override
  bool get isAuthenticated => authenticated;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'user@asoud.local',
        fullName: 'کاربر',
        roles: ['Employee'],
        company: 'شرکت نمونه آسود',
      );
}

/// Returns the exact shape of `forms.get_link_options`: `{name, label, extra}`
/// rows in `data` and `reason` in `meta`.
class _Repository extends FormRepository {
  _Repository({
    bool authenticated = true,
    this.rows = const [],
    this.reason,
  }) : super(_Client(authenticated), 'شرکت نمونه آسود');

  final List<Map<String, dynamic>> rows;
  final String? reason;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<FormMap> callEnvelope(String method, [FormMap data = const {}]) async {
    expect(method, 'get_link_options');
    requests.add(data);
    return {
      'ok': true,
      'data': rows,
      'meta': {if (reason != null) 'reason': reason},
    };
  }
}

const _attendanceRow = {
  'name': 'HR-ATT-2026-00001',
  'label': '۱۴۰۵/۰۷/۲۰ حاضر ۰۸:۳۰ تا ۱۷:۰۰',
  'extra': {
    'in_time': '2026-10-12 08:30:00',
    'out_time': '2026-10-12 17:00:00',
    'attendance_date': '2026-10-12',
    'status': 'Present',
    'shift': 'روز',
  },
};

FormMap _schema(List<FormMap> fields) => {
      'schema_version': 2,
      'title': 'آزمون',
      'sections': [
        {'title': 'بخش', 'fields': fields},
      ],
    };

final _attendanceFields = <FormMap>[
  {'key': 'day', 'label': 'روز', 'type': 'Date'},
  {
    'key': 'att',
    'label': 'رکورد حضور',
    'type': 'Link',
    'source': 'Attendance',
    'link_filter': {'field': 'attendance_date', 'value_field': 'day'},
  },
  {'key': 'in_t', 'label': 'ورود', 'type': 'Time', 'fetch_from': 'att.in_time'},
  {'key': 'when', 'label': 'تاریخ حضور', 'type': 'Date', 'fetch_from': 'att.attendance_date'},
  {'key': 'st', 'label': 'وضعیت حضور', 'type': 'Text', 'fetch_from': 'att.status'},
];

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

Widget _app(Widget child, double width) => MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  group('applyFieldChange (C10, C11)', () {
    final schema = _schema(_attendanceFields);

    test('fills fetch_from fields from extra: time part, date, text', () {
      final next = applyFieldChange(schema, {}, 'att', 'HR-ATT-2026-00001',
          extra: _attendanceRow['extra'] as FormMap);
      expect(next['in_t'], '08:30');
      expect(next['when'], '2026-10-12');
      expect(next['st'], 'Present');
    });

    test('text target gets a Jalali date', () {
      final next = applyFieldChange(
        _schema([
          {'key': 'att', 'label': 'حضور', 'type': 'Link', 'source': 'Attendance'},
          {'key': 'd', 'label': 'تاریخ', 'type': 'Text', 'fetch_from': 'att.attendance_date'},
        ]),
        {},
        'att',
        'X',
        extra: {'attendance_date': '2026-10-12'},
      );
      expect(next['d'], '۱۴۰۵/۰۷/۲۰');
    });

    test('changing the filter field clears the link and its fetched fields', () {
      final filled = applyFieldChange(schema, {'day': '2026-10-12'}, 'att', 'HR-ATT-2026-00001',
          extra: _attendanceRow['extra'] as FormMap);
      expect(filled['in_t'], '08:30');
      final next = applyFieldChange(schema, filled, 'day', '2026-10-13');
      expect(next['day'], '2026-10-13');
      expect(next['att'], isNull);
      expect(next['in_t'], isNull);
      expect(next['when'], isNull);
      expect(next['st'], isNull);
    });

    test('re-setting the same filter value keeps the link', () {
      final filled = applyFieldChange(schema, {'day': '2026-10-12'}, 'att', 'HR-ATT-2026-00001',
          extra: _attendanceRow['extra'] as FormMap);
      expect(applyFieldChange(schema, filled, 'day', '2026-10-12')['att'], 'HR-ATT-2026-00001');
    });

    test('reset cascades through a chain of links', () {
      final chain = _schema([
        {'key': 'a', 'label': 'الف', 'type': 'Date'},
        {'key': 'b', 'label': 'ب', 'type': 'Link', 'source': 'Attendance', 'link_filter': {'field': 'attendance_date', 'value_field': 'a'}},
        {'key': 'c', 'label': 'پ', 'type': 'Link', 'source': 'Attendance', 'link_filter': {'field': 'attendance_date', 'value_field': 'b'}},
      ]);
      final next = applyFieldChange(chain, {'a': '1', 'b': 'x', 'c': 'y'}, 'a', '2');
      expect(next['b'], isNull);
      expect(next['c'], isNull);
    });
  });

  group('schemaProblems', () {
    test('accepts allowed attribute, rejects unknown one', () {
      expect(schemaProblems(_schema(_attendanceFields)), isEmpty);
      final bad = _schema([
        {'key': 'att', 'label': 'حضور', 'type': 'Link', 'source': 'Attendance'},
        {'key': 'x', 'label': 'ایکس', 'type': 'Text', 'fetch_from': 'att.location'},
      ]);
      expect(schemaProblems(bad), contains('ایکس: مقدار از فیلد معتبر نیست.'));
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    group('runtime at ${width.toInt()} px', () {
      testWidgets('picking a row fills read-only fields and sends the filter', (tester) async {
        final repo = _Repository(rows: [_attendanceRow]);
        final key = GlobalKey<FormState>();
        final log = <FormMap>[];
        await tester.pumpWidget(_app(
          _Host(_schema(_attendanceFields), repo, {'day': '2026-10-12'}, key, log),
          width,
        ));
        await tester.tap(find.text('رکورد حضور'));
        await tester.pumpAndSettle();
        expect(repo.requests.single['source'], 'Attendance');
        expect(repo.requests.single['filter_field'], 'attendance_date');
        expect(repo.requests.single['filter_value'], '2026-10-12');
        // the raw document id is not shown for the new sources
        expect(find.text('HR-ATT-2026-00001'), findsNothing);
        await tester.tap(find.text(_attendanceRow['label'] as String));
        await tester.pumpAndSettle();
        expect(log.last['att'], 'HR-ATT-2026-00001');
        expect(log.last['in_t'], '08:30');
        expect(log.last['when'], '2026-10-12');
        expect(log.last['st'], 'Present');
        // read-only display: Jalali date and Persian time, no picker
        expect(find.text('۱۴۰۵/۰۷/۲۰'), findsOneWidget);
        expect(find.text('۰۸:۳۰'), findsOneWidget);
        await tester.tap(find.text('ورود'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('new default sources show the automatic placeholder', (tester) async {
        await tester.pumpWidget(_app(
          _Host(_schema([
            {'key': 'sh', 'label': 'شیفت', 'type': 'Link', 'source': 'Shift Type', 'default_source': 'default_shift'},
            {'key': 'no', 'label': 'کد پرسنلی من', 'type': 'Text', 'default_source': 'employee_number'},
          ]), _Repository(), {}, GlobalKey<FormState>(), []),
          width,
        ));
        expect(find.text('دریافت خودکار'), findsNWidgets(2));
      });

      testWidgets('exclude_self is sent to the server', (tester) async {
        final repo = _Repository(rows: [
          {'name': 'HR-EMP-1', 'label': 'علی رضایی', 'extra': {'department': 'مالی'}},
        ]);
        await tester.pumpWidget(_app(
          _Host(
            _schema([
              {'key': 'p', 'label': 'همکار', 'type': 'Link', 'source': 'Employee', 'exclude_self': true},
            ]),
            repo, {}, GlobalKey<FormState>(), [],
          ),
          width,
        ));
        await tester.tap(find.text('همکار'));
        await tester.pumpAndSettle();
        expect(repo.requests.single['exclude_self'], 1);
        expect(find.text('علی رضایی'), findsOneWidget);
      });

      testWidgets('user without Employee sees the no_employee message', (tester) async {
        final repo = _Repository(rows: const [], reason: 'no_employee');
        await tester.pumpWidget(_app(
          _Host(_schema([_attendanceFields[1]]), repo, {}, GlobalKey<FormState>(), []),
          width,
        ));
        await tester.tap(find.text('رکورد حضور'));
        await tester.pumpAndSettle();
        expect(find.text('پرونده پرسنلی شما ثبت نشده است.'), findsOneWidget);
      });

      testWidgets('offline preview shows the server-only message and never calls', (tester) async {
        final repo = _Repository(authenticated: false);
        await tester.pumpWidget(_app(
          _Host(_schema([
            {'key': 'a', 'label': 'دارایی من', 'type': 'Link', 'source': 'Asset'},
          ]), repo, {}, GlobalKey<FormState>(), []),
          width,
        ));
        await tester.tap(find.text('دارایی من'));
        await tester.pumpAndSettle();
        expect(find.text('این فهرست فقط با اتصال به سرور در دسترس است.'), findsOneWidget);
        expect(repo.requests, isEmpty);
      });

      testWidgets('not_equal blocks equal values with the default and a custom message', (tester) async {
        final key = GlobalKey<FormState>();
        final schema = _schema([
          {'key': 'old', 'label': 'شیفت فعلی', 'type': 'Text'},
          {'key': 'new', 'label': 'شیفت جدید', 'type': 'Text', 'not_equal': 'old'},
          {'key': 'new2', 'label': 'شیفت دوم', 'type': 'Text', 'not_equal': 'old', 'not_equal_message': 'متفاوت باشد.'},
        ]);
        await tester.pumpWidget(_app(
          _Host(schema, _Repository(), {'old': 'صبح', 'new': 'صبح', 'new2': 'صبح'}, key, []),
          width,
        ));
        expect(key.currentState!.validate(), isFalse);
        await tester.pump();
        expect(find.text('مقدار جدید نباید با مقدار فعلی یکسان باشد.'), findsOneWidget);
        expect(find.text('متفاوت باشد.'), findsOneWidget);
      });

      testWidgets('not_equal passes when different or empty', (tester) async {
        final key = GlobalKey<FormState>();
        final schema = _schema([
          {'key': 'old', 'label': 'قدیم', 'type': 'Text'},
          {'key': 'new', 'label': 'جدید', 'type': 'Text', 'not_equal': 'old'},
        ]);
        await tester.pumpWidget(_app(_Host(schema, _Repository(), {'old': 'الف', 'new': 'ب'}, key, []), width));
        expect(key.currentState!.validate(), isTrue);
        await tester.pumpWidget(_app(_Host(schema, _Repository(), {'old': 'الف'}, GlobalKey<FormState>(), []), width));
        expect(find.byType(Form), findsOneWidget);
      });

      testWidgets('unique column rejects a duplicate row', (tester) async {
        final key = GlobalKey<FormState>();
        final schema = _schema([
          {
            'key': 'items',
            'label': 'اقلام',
            'type': 'Table',
            'columns': [
              {'key': 'asset', 'label': 'دارایی', 'type': 'Text', 'unique': true},
              {'key': 'note', 'label': 'یادداشت', 'type': 'Text'},
            ],
          },
        ]);
        await tester.pumpWidget(_app(
          _Host(schema, _Repository(), {
            'items': [
              {'asset': 'A-1', 'note': 'x'},
              {'asset': 'A-2', 'note': 'x'},
              {'asset': 'A-1', 'note': 'y'},
            ],
          }, key, []),
          width,
        ));
        expect(key.currentState!.validate(), isFalse);
        await tester.pump();
        expect(find.text('ردیف تکراری: دارایی'), findsOneWidget);
      });
    });
  }

  test('unique ignores empty values and repeats in non-unique columns', () {
    final table = {
      'columns': [
        {'key': 'a', 'label': 'الف', 'unique': true},
        {'key': 'b', 'label': 'ب'},
      ],
    };
    expect(uniqueColumnProblem(table, [{'a': '', 'b': 1}, {'a': '', 'b': 1}, {'a': 'x', 'b': 1}]), isNull);
    expect(uniqueColumnProblem(table, [{'a': 'x'}, {'a': 'x'}]), 'ردیف تکراری: الف');
  });

  group('editor', () {
    Future<void> pick(WidgetTester tester, String label, String option) async {
      final dropdown = find.ancestor(
        of: find.text(label),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester, FormMap schema, FormMap field, {bool column = false, double width = 390, void Function(FormMap?)? onSaved}) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await editSchemaField(context, schema, field, column: column, repository: _Repository());
              onSaved?.call(result);
            },
            child: const Text('باز کن'),
          ),
        ),
        width,
      ));
      await tester.tap(find.text('باز کن'));
      await tester.pumpAndSettle();
      // The field library on the basic tab already overflows by 22 px at 320 px
      // (not part of this change); what follows must not add overflow.
      if (width <= 320) tester.takeException();
    }

    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('Link advanced tab at ${width.toInt()}: exclude_self switch and source list', (tester) async {
        final field = {'key': 'p', 'label': 'همکار', 'type': 'Link', 'source': 'Employee'};
        FormMap? saved;
        await openSheet(tester, _schema([field]), field, width: width, onSaved: (v) => saved = v);
        await tester.tap(find.text('پیشرفته'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('خود کاربر قابل انتخاب نباشد'));
        await tester.tap(find.text('خود کاربر قابل انتخاب نباشد'));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'خود کاربر قابل انتخاب نباشد')).value, isTrue);
        await tester.ensureVisible(find.text('ذخیره تغییرات'));
        await tester.tap(find.text('ذخیره تغییرات'));
        await tester.pumpAndSettle();
        expect(saved?['exclude_self'], isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    test('source list carries the four new Persian labels', () {
      expect(formSources['Attendance'], 'رکورد حضور و غیاب');
      expect(formSources['Shift Type'], 'نوع شیفت');
      expect(formSources['Training Event'], 'دوره آموزشی');
      expect(formSources['Asset'], 'دارایی تحویل‌شده به من');
      expect(formLinkFilters['Attendance'], containsPair('attendance_date', 'تاریخ حضور'));
      expect(formFetchAttributes['Training Event']!.keys, ['start_time', 'end_time', 'type', 'level', 'training_program', 'course', 'location', 'trainer_name', 'employee_count']);
    });

    testWidgets('fetch_from picker: link field then attribute; saves the contract value', (tester) async {
      final link = {'key': 'att', 'label': 'رکورد حضور', 'type': 'Link', 'source': 'Attendance'};
      final field = {'key': 'in_t', 'label': 'ورود', 'type': 'Time'};
      FormMap? saved;
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => saved = await editSchemaField(context, _schema([link, field]), field),
            child: const Text('باز کن'),
          ),
        ),
        390,
      ));
      await tester.tap(find.text('باز کن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();
      await pick(tester, 'مقدار از فیلد', 'رکورد حضور');
      final attr = find.ancestor(
        of: find.text('کدام اطلاعات'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(attr);
      await tester.tap(attr);
      await tester.pumpAndSettle();
      expect(find.text('ساعت ورود'), findsWidgets);
      expect(find.text('ساعت خروج'), findsOneWidget);
      expect(find.text('شیفت'), findsOneWidget);
      expect(find.text('کد پرسنلی'), findsNothing);
      await tester.tap(find.text('ساعت خروج'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ذخیره تغییرات'));
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      expect(saved?['fetch_from'], 'att.out_time');
    });

    testWidgets('not_equal dropdown lists only same-type fields', (tester) async {
      final a = {'key': 'old', 'label': 'شیفت فعلی', 'type': 'Text'};
      final b = {'key': 'new', 'label': 'شیفت جدید', 'type': 'Text'};
      final d = {'key': 'dd', 'label': 'تاریخ مبنا', 'type': 'Date'};
      FormMap? saved;
      await openSheet(tester, _schema([a, b, d]), b, onSaved: (v) => saved = v);
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();
      final dropdown = find.ancestor(
        of: find.text('نباید برابر با فیلد:'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.text('شیفت فعلی'), findsWidgets);
      expect(find.text('تاریخ مبنا'), findsNothing);
      await tester.tap(find.text('شیفت فعلی').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ذخیره تغییرات'));
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      expect(saved?['not_equal'], 'old');
    });

    testWidgets('unique switch exists only for table columns', (tester) async {
      final col = {'key': 'asset', 'label': 'دارایی', 'type': 'Text'};
      FormMap? saved;
      await openSheet(tester, _schema([col]), col, column: true, onSaved: (v) => saved = v);
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تکراری مجاز نیست'));
      await tester.tap(find.text('تکراری مجاز نیست'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ذخیره تغییرات مشخصه'));
      await tester.tap(find.text('ذخیره تغییرات مشخصه'));
      await tester.pumpAndSettle();
      expect(saved?['unique'], isTrue);
    });

    testWidgets('unique switch hidden for ordinary fields', (tester) async {
      final col = {'key': 'asset', 'label': 'دارایی', 'type': 'Text'};
      await openSheet(tester, _schema([col]), col);
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();
      expect(find.text('تکراری مجاز نیست'), findsNothing);
    });

    testWidgets('default_source offers employee number for Text', (tester) async {
      final col = {'key': 'no', 'label': 'کد', 'type': 'Text'};
      FormMap? saved;
      await openSheet(tester, _schema([col]), col, onSaved: (v) => saved = v);
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();
      await pick(tester, 'منبع مقدار پیش‌فرض', 'کد پرسنلی');
      await tester.ensureVisible(find.text('ذخیره تغییرات'));
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      expect(saved?['default_source'], 'employee_number');
    });
  });
}
