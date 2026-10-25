import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Administrator client with the real backend envelope shapes; the write goes
/// through [callAsoudMethod], exactly as [OrganizationRepository.save] calls it.
class _OrgClient extends Fake implements FrappeApiClient {
  _OrgClient({List<Map<String, dynamic>> units = const [], this.positions}) : units = List.of(units);
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>>? positions;
  bool failUnits = false;
  bool rejectSave = false;
  Map<String, dynamic>? lastUnitPayload;
  final writes = <String>[];
  Map<String, dynamic>? lastSavePayload;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: const ['Administrator'],
      );

  Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': data,
        },
      };

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.get_chart') {
      return _envelope({
        'rows': lastSavePayload?['rows'] ?? positions ?? [
          {
            'code': 'CEO',
            'title': 'مدیرعامل',
            'parent': '',
            'department': 'مدیریت',
            'employee': 'EMP-001',
          }
        ],
        'revision': lastSavePayload == null ? 1 : (lastSavePayload!['revision'] as int) + 1,
        'warnings': <dynamic>[],
      });
    }
    if (method == 'asoud_erp.api.v1.organization.list_employees') {
      return _envelope({'employees': <dynamic>[]});
    }
    if (method == 'asoud_erp.api.v1.organization.list_units') {
      if (failUnits) {
        throw const ApiException(
            kind: ApiFailureKind.network, message: 'offline');
      }
      return _envelope({'units': units, 'can_manage': true});
    }
    if (method == 'asoud_erp.api.v1.organization.save_unit') {
      lastUnitPayload = Map<String, dynamic>.from(data!['payload'] as Map);
      final id = lastUnitPayload!['name'] ?? 'NEW-UNIT';
      units.removeWhere((u) => u['name'] == id);
      units.add({'name': id, 'department_name': lastUnitPayload!['title'],
        'parent_department': lastUnitPayload!['parent'], 'is_group': 1,
        'disabled': 0, 'modified': '2026-10-25 10:00:00'});
      return _envelope({'name': id, 'modified': '2026-10-25 10:00:00'});
    }
    if (method == 'asoud_erp.api.v1.organization.employee_photo') return _envelope({'content': null});
    throw StateError('Unexpected organization read: $method');
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.organization.save_chart') {
      if (rejectSave) throw const ApiException(kind: ApiFailureKind.validation, message: 'ذخیره توسط سرور رد شد.');
      writes.add(method);
      final payload = Map<String, dynamic>.from(data!['payload'] as Map);
      lastSavePayload = payload;
      return {
        'rows': payload['rows'],
        'revision': (payload['revision'] as int) + 1,
        'warnings': <dynamic>[],
      };
    }
    throw StateError('Unexpected organization write: $method');
  }
}

Future<void> _openCreateForm(WidgetTester tester, _OrgClient client,
    {bool openForm = true}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository =
      OrganizationRepository(client, local: FakeLocalRecordStore());
  addTearDown(repository.dispose);
  await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
    value: client,
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OrganizationPage(
          company: 'شرکت نمونه آسود',
          repository: repository,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  if (!openForm) return;
  await tester.tap(find.text('جایگاه‌ها'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('عملیات جایگاه'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ویرایش جایگاه'));
  await tester.pumpAndSettle();
}

void main() {
  const unit = {
    'name': 'HR-CO',
    'department_name': 'منابع انسانی',
    'parent_department': 'All Departments',
    'is_group': 1,
    'disabled': 0,
    'modified': '2026-10-22 10:00:00'
  };

  testWidgets('focused organization reference render', (tester) async {
    await (FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final client = _OrgClient(units: [
      {...unit, 'name': 'SALES', 'department_name': 'فروش و بازاریابی'},
      {...unit, 'name': 'MARKETING', 'department_name': 'بازاریابی', 'parent_department': 'SALES'},
      for (final entry in {'DIGITAL': 'بازاریابی دیجیتال', 'PR': 'روابط عمومی', 'RESEARCH': 'تحقیقات بازار', 'ADS': 'تبلیغات'}.entries)
        {...unit, 'name': entry.key, 'department_name': entry.value, 'parent_department': 'MARKETING'},
    ], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
      {'code': 'MARKETER', 'title': 'مدیر بازاریابی', 'parent': 'CEO', 'department_id': 'MARKETING',
        'department': 'بازاریابی', 'occupants': <String>[], 'capacity': 1, 'duties': 'برنامه‌ریزی و هماهنگی فعالیت‌های بازاریابی'},
    ]);
    await _openCreateForm(tester, client, openForm: false);
    tester.view.physicalSize = const Size(390, 2400);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-unit-MARKETING')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('عملیات مدیر بازاریابی'));
    await tester.tap(find.byTooltip('عملیات مدیر بازاریابی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش جایگاه'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const PageStorageKey('organization-focused-scroll')), const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(OrganizationPage), matchesGoldenFile('../../../build/organization-focus-reference.png'));
  }, tags: 'golden', skip: !const bool.fromEnvironment('ORG_VISUAL'));

  testWidgets('focused children paginate four at a time and retain native path', (tester) async {
    final client = _OrgClient(units: [unit, for (var i = 0; i < 9; i++) {
      ...unit, 'name': 'CHILD-$i', 'department_name': 'واحد $i', 'parent_department': 'HR-CO',
    }]);
    await _openCreateForm(tester, client, openForm: false);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-4')), findsNothing);
    final first = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-0')));
    final second = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-1')));
    final third = tester.getRect(find.byKey(const ValueKey('focus-unit-CHILD-2')));
    expect(first.top, second.top);
    expect(third.top, greaterThan(first.bottom));
    await tester.tap(find.byTooltip('صفحه بعد'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-CHILD-0')), findsNothing);
    expect(find.byKey(const ValueKey('focus-unit-CHILD-7')), findsOneWidget);
    await tester.tap(find.byTooltip('صفحه بعد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-unit-CHILD-8')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
    expect(find.text('زیرواحدی تعریف نشده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected inline save retains input and never announces success', (tester) async {
    final client = _OrgClient(units: [unit])..rejectSave = true;
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('جایگاه جدید'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('focus-editor-title'));
    await tester.enterText(title, 'کارشناس بررسی');
    await tester.ensureVisible(find.text('ذخیره').last);
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(title).controller!.text, 'کارشناس بررسی');
    expect(find.text('ذخیره توسط سرور رد شد.'), findsOneWidget);
    expect(find.text('تغییرات ذخیره شد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position selection and inline editing preserve occupants and unit path', (tester) async {
    final client = _OrgClient(units: [unit], positions: [
      {'code': 'CEO', 'title': 'مدیرعامل', 'parent': '', 'occupants': <String>[], 'capacity': 1},
      {'code': 'P1', 'title': 'مدیر آموزش', 'parent': 'CEO', 'department_id': 'HR-CO',
        'department': 'منابع انسانی', 'occupants': ['employee:A', 'employee:B'], 'capacity': 2,
        'assignment_history': [{'employee': 'employee:A', 'started_at': null, 'ended_at': null}]},
    ]);
    await _openCreateForm(tester, client, openForm: false);
    final card = find.byKey(const ValueKey('focus-position-P1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-unit-P1')), findsNothing);
    await tester.tap(find.byTooltip('عملیات مدیر آموزش'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش جایگاه'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('focus-editor-title')), 'مدیر یادگیری');
    await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۱');
    await tester.ensureVisible(find.text('ذخیره تغییرات'));
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('ظرفیت کمتر از تعداد متصدیان فعال مجاز نیست.'), findsOneWidget);
    expect(client.lastSavePayload, isNull);
    await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۳');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    final saved = (client.lastSavePayload!['rows'] as List).last as Map;
    expect(saved['code'], 'P1');
    expect(saved['department_id'], 'HR-CO');
    expect(saved['occupants'], ['employee:A', 'employee:B']);
    expect(saved['assignment_history'], hasLength(1));
    expect(saved['title'], 'مدیر یادگیری');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('focused inline position form saves native context at $width', (tester) async {
      final client = _OrgClient(units: [unit]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = Size(width, 1800);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('جایگاه جدید'));
      await tester.tap(find.text('جایگاه جدید'));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('focus-editor-title'));
      expect(tester.widget<AppTextField>(title).controller!.text, isEmpty);
      await tester.enterText(title, 'کارشناس توسعه');
      await tester.enterText(find.byKey(const ValueKey('focus-editor-capacity')), '۲');
      await tester.ensureVisible(find.text('ذخیره').last);
      await tester.tap(find.text('ذخیره').last);
      await tester.pumpAndSettle();
      final saved = (client.lastSavePayload!['rows'] as List).last as Map;
      expect(saved['department_id'], 'HR-CO');
      expect(saved['occupants'], isEmpty);
      expect(saved['capacity'], 2);
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-editor-title')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsaved inline subunit prompts before changing context and persists fixed parent', (tester) async {
    final client = _OrgClient(units: [unit, {...unit, 'name': 'CHILD', 'department_name': 'آموزش', 'parent_department': 'HR-CO'}]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('زیرواحد جدید'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('focus-editor-title'));
    await tester.enterText(title, 'پشتیبانی');
    await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-CHILD')));
    await tester.tap(find.byKey(const ValueKey('focus-unit-CHILD')));
    await tester.pumpAndSettle();
    expect(find.text('تغییرات ذخیره‌نشده'), findsOneWidget);
    await tester.tap(find.text('ادامه ویرایش'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(title).controller!.text, 'پشتیبانی');
    expect(client.lastUnitPayload, isNull);
    await tester.ensureVisible(find.text('ذخیره').last);
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!['parent'], 'HR-CO');
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.ensureVisible(find.byKey(const ValueKey('focus-unit-NEW-UNIT')));
    expect(find.text('زیرواحدهای مستقیم منابع انسانی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('unit management keeps root and all direct children at $width', (tester) async {
      final client = _OrgClient(units: [unit, {
        ...unit, 'name': 'CHILD-A', 'department_name': 'آموزش', 'parent_department': 'HR-CO',
      }, {
        ...unit, 'name': 'CHILD-B', 'department_name': 'جذب', 'parent_department': 'HR-CO',
      }]);
      await _openCreateForm(tester, client, openForm: false);
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpAndSettle();
      expect(find.text('مدیرعامل'), findsOneWidget);
      await tester.ensureVisible(find.text('منابع انسانی').first);
      await tester.tap(find.text('منابع انسانی').first);
      await tester.pumpAndSettle();
      // Selection now expands in place, without the old management route.
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      expect(find.text('مدیرعامل'), findsOneWidget);
      expect(find.text('آموزش'), findsOneWidget);
      expect(find.text('جذب'), findsOneWidget);
      expect(find.text('زیرواحدهای مستقیم منابع انسانی'), findsOneWidget);
      expect(client.lastUnitPayload, isNull);
      await tester.tap(find.text('آموزش'));
      await tester.pumpAndSettle();
      expect(find.text('زیرواحدی تعریف نشده است.'), findsOneWidget);
      expect(find.text('جذب'), findsNothing);
      expect(find.byKey(const ValueKey('focus-unit-HR-CO')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('focus-unit-HR-CO')));
      await tester.pumpAndSettle();
      expect(find.text('جذب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unit details opens as a page with inline editing and management',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('واحدها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('organization-unit-edit')), findsOneWidget);
    expect(find.text('ویرایش مشخصات واحد'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('جزئیات واحد سازمانی'), findsOneWidget);
    expect(find.text('جابه‌جایی واحد'), findsOneWidget);
    expect(find.text('حذف واحد'), findsOneWidget);
    expect(find.textContaining('All Departments'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('organization-unit-edit')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'عنوان واحد'), findsOneWidget);
    expect(find.text('ذخیره'), findsOneWidget);
    expect(client.lastUnitPayload, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a subunit starts blank and does not edit its parent',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('واحدها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('organization-subunit-add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final title = find.widgetWithText(TextFormField, 'عنوان واحد *');
    expect(tester.widget<TextFormField>(title).controller!.text, isEmpty);
    await tester.enterText(title, 'آموزش');
    final submit = find.byKey(const ValueKey('organization-unit-submit'));
    expect(submit, findsOneWidget);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(client.lastUnitPayload!.containsKey('name'), isFalse);
    expect(client.lastUnitPayload!['parent'], 'HR-CO');
    expect(client.lastUnitPayload!['title'], 'آموزش');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline position creation preserves the native unit and creates no assignment',
      (tester) async {
    final client = _OrgClient(units: [unit]);
    await _openCreateForm(tester, client, openForm: false);
    await tester.tap(find.text('واحدها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('organization-inline-position-open'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final save =
        find.byKey(const ValueKey('organization-inline-position-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان جایگاه جدید'),
        'کارشناس آموزش');
    // onChanged schedules the rebuild that enables the save button.
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(client.lastSavePayload, isNotNull,
        reason: 'Saving the inline position must reach the repository.');
    final rows = (client.lastSavePayload!['rows'] as List).cast<Map>();
    final added = rows.singleWhere((r) => r['title'] == 'کارشناس آموزش');
    expect(added['department_id'], 'HR-CO');
    expect(added['occupants'], isEmpty);
    expect(added['capacity'], 1);
    expect(rows.any((r) => r['code'] == 'CEO'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'assignment page shows real capacity and retains assignment history tab',
      (tester) async {
    await _openCreateForm(tester, _OrgClient(), openForm: false);
    await tester.tap(find.text('جایگاه‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدیرعامل'));
    await tester.pumpAndSettle();
    final assignments = find.text('انتساب پرسنل و سوابق');
    await tester.ensureVisible(assignments);
    await tester.tap(assignments);
    await tester.pumpAndSettle();
    expect(find.text('ظرفیت کل'), findsOneWidget);
    expect(find.text('ظرفیت خالی'), findsOneWidget);
    expect(find.text('ظرفیت جایگاه تکمیل است.'), findsOneWidget);
    await tester.tap(find.text('سوابق انتساب').last);
    await tester.pumpAndSettle();
    expect(find.text('سابقه‌ای ثبت نشده است.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('organization management and visual report fit at $width',
        (tester) async {
      final client = _OrgClient();
      await _openCreateForm(tester, client);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      expect(find.text('واحدها'), findsOneWidget);
      expect(find.text('جایگاه‌ها'), findsOneWidget);
      await tester.tap(find.text('واحدها'));
      await tester.pumpAndSettle();
      expect(find.text('هنوز واحدی تعریف نشده است.'), findsOneWidget);
      await tester.tap(find.text('جایگاه‌ها'));
      await tester.pumpAndSettle();
      expect(find.text('جایگاه‌های سازمانی'), findsOneWidget);
      await tester.tap(find.text('چارت سازمانی'));
      await tester.pumpAndSettle();
      final report = find.text('گزارش تصویری چارت');
      // A cached child can exist below the viewport in NestedScrollView.
      // Real gestures scroll both coordinated viewports; wait for a hit target,
      // not merely for the lazy child to have been built.
      for (var attempt = 0;
          attempt < 20 && report.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byType(TabBarView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(report.hitTestable(), findsOneWidget);
      await tester.tap(report.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('نمای فهرستی'), findsOneWidget);
      expect(find.text('ورود از اکسل'), findsOneWidget);
      expect(find.text('ایجاد دستی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the visual report still renders when the units list fails',
      (tester) async {
    final client = _OrgClient()..failUnits = true;
    await _openCreateForm(tester, client);
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    final report = find.text('گزارش تصویری چارت');
    for (var attempt = 0;
        attempt < 20 && report.hitTestable().evaluate().isEmpty;
        attempt++) {
      await tester.drag(find.byType(TabBarView), const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    await tester.tap(report.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-units-unavailable')),
        findsOneWidget);
    expect(find.text('مدیرعامل'), findsWidgets);
    expect(find.text('دریافت اطلاعات ناموفق بود؛ تلاش دوباره'), findsNothing);
  });

  testWidgets('the position form uses AppTextField and AppSelectField',
      (tester) async {
    await _openCreateForm(tester, _OrgClient());

    expect(find.text('عنوان جایگاه *'), findsOneWidget);
    expect(find.text('کد جایگاه *'), findsNothing);
    expect(find.widgetWithText(AppSelectField, 'واحد سازمانی'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.byType(AppSelectField), findsNWidgets(2));
    expect(find.text('ظرفیت *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position edit keeps its code and occupants', (tester) async {
    final client = _OrgClient();
    await _openCreateForm(tester, client);
    final title = find.widgetWithText(TextFormField, 'عنوان جایگاه *');
    await tester.enterText(title, '');
    await tester.tap(find.text('ثبت تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('عنوان جایگاه را وارد کنید.'), findsOneWidget);
    await tester.enterText(title, 'مدیر ارشد');
    await tester.tap(find.text('ثبت تغییرات'));
    await tester.pumpAndSettle();
    final rows = (client.lastSavePayload!['rows'] as List).cast<Map>();
    final edited = rows.singleWhere((r) => r['code'] == 'CEO');
    expect(edited['title'], 'مدیر ارشد');
    expect(edited['occupants'], ['EMP-001']);
    expect(rows.length, 1);
    expect(tester.takeException(), isNull);
  });
}
